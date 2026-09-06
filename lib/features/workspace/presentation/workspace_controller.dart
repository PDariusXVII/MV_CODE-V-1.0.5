import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_error_reporter.dart';
import '../data/workspace_repository.dart';
import '../domain/workspace_entry.dart';

enum ClipboardMode { copy, cut }

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this._repository);

  static const String _workspaceKey = 'workspace.rootUri';

  final WorkspaceRepository _repository;
  final Map<String, List<WorkspaceEntry>> _children =
      <String, List<WorkspaceEntry>>{};
  final Map<String, String> _contentCache = <String, String>{};
  final Map<String, Future<String>> _pendingReads = <String, Future<String>>{};
  final Set<String> _expanded = <String>{};
  final List<OpenDocument> _documents = <OpenDocument>[];

  WorkspaceEntry? _root;
  WorkspaceEntry? _selected;
  String? _activeUri;
  WorkspaceEntry? _clipboard;
  ClipboardMode? _clipboardMode;
  bool _busy = false;
  String? _message;

  WorkspaceEntry? get root => _root;
  WorkspaceEntry? get selected => _selected;
  List<OpenDocument> get documents =>
      List<OpenDocument>.unmodifiable(_documents);
  OpenDocument? get activeDocument => documentByUri(_activeUri);
  WorkspaceEntry? get clipboard => _clipboard;
  ClipboardMode? get clipboardMode => _clipboardMode;
  bool get busy => _busy;
  String? get message => _message;
  bool get hasWorkspace => _root != null;
  List<WorkspaceEntry> get loadedFiles =>
      _children.values
          .expand((List<WorkspaceEntry> entries) => entries)
          .where((WorkspaceEntry entry) => !entry.isDirectory)
          .toSet()
          .toList()
        ..sort(
          (WorkspaceEntry a, WorkspaceEntry b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

  List<WorkspaceEntry> childrenOf(String uri) =>
      List<WorkspaceEntry>.unmodifiable(_children[uri] ?? <WorkspaceEntry>[]);

  bool isExpanded(String uri) => _expanded.contains(uri);
  bool isLoaded(String uri) => _children.containsKey(uri);

  OpenDocument? documentByUri(String? uri) {
    if (uri == null) return null;
    for (final OpenDocument document in _documents) {
      if (document.uri == uri) return document;
    }
    return null;
  }

  Future<void> restoreWorkspace() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? uri = prefs.getString(_workspaceKey);
    if (uri == null || uri.isEmpty) return;
    await _run(() async {
      final WorkspaceEntry? entry = await _repository.inspect(uri);
      if (entry == null || !entry.isDirectory) {
        await prefs.remove(_workspaceKey);
        return;
      }
      _root = entry;
      _selected = entry;
      await _loadDirectory(entry.uri, expand: true);
    }, silent: true);
  }

  Future<void> pickWorkspace() async {
    await _run(() async {
      final WorkspaceEntry? entry = await _repository.pickWorkspace();
      if (entry == null) return;
      _root = entry;
      _selected = entry;
      _children.clear();
      _expanded.clear();
      _documents.clear();
      _contentCache.clear();
      _pendingReads.clear();
      _activeUri = null;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_workspaceKey, entry.uri);
      await _loadDirectory(entry.uri, expand: true);
      _message = 'Pasta aberta: ${entry.name}';
    });
  }

  Future<void> refresh([String? uri]) async {
    final String? target = uri ?? _root?.uri;
    if (target == null) return;
    await _run(
      () => _loadDirectory(target, expand: _expanded.contains(target)),
    );
  }

  Future<void> toggleDirectory(WorkspaceEntry entry) async {
    _selected = entry;
    if (_expanded.remove(entry.uri)) {
      notifyListeners();
      return;
    }
    await _run(() => _loadDirectory(entry.uri, expand: true));
  }

  Future<void> _loadDirectory(String uri, {required bool expand}) async {
    _children[uri] = await _repository.listChildren(uri);
    if (expand) _expanded.add(uri);
  }

  void select(WorkspaceEntry entry) {
    _selected = entry;
    notifyListeners();
  }

  Future<void> openFile(WorkspaceEntry entry) async {
    if (entry.isDirectory) {
      await toggleDirectory(entry);
      return;
    }
    _selected = entry;
    final OpenDocument? existing = documentByUri(entry.uri);
    if (existing != null) {
      _activeUri = existing.uri;
      notifyListeners();
      return;
    }
    final String? cached = _contentCache[entry.uri];
    final OpenDocument document = OpenDocument(
      entry: entry,
      initialContent: cached ?? '',
      loading: cached == null,
    );
    _documents.add(document);
    _activeUri = entry.uri;
    notifyListeners();

    if (cached == null) unawaited(_loadDocumentContent(document));
  }

  Future<void> _loadDocumentContent(OpenDocument document) async {
    try {
      final String content = await _readText(document.uri);
      final int index = _documents.indexOf(document);
      if (index < 0) return;
      final OpenDocument updated = OpenDocument(
        entry: document.entry,
        initialContent: document.dirty ? document.initialContent : content,
        loading: false,
      )..dirty = document.dirty;
      _documents[index] = updated;
      notifyListeners();
    } catch (error, stack) {
      document.loading = false;
      AppErrorReporter.record(error, stack);
      _message = error.toString();
      notifyListeners();
    }
  }

  void activate(String uri) {
    if (documentByUri(uri) == null) return;
    _activeUri = uri;
    notifyListeners();
  }

  void updateDocumentContent(String uri, String content) {
    final OpenDocument? document = documentByUri(uri);
    if (document == null || document.loading) return;

    document.initialContent = content;
    if (!document.dirty) {
      document.dirty = true;
      notifyListeners();
    }
  }

  void markDirty(String uri) {
    final OpenDocument? document = documentByUri(uri);
    if (document == null || document.dirty) return;
    document.dirty = true;
    notifyListeners();
  }

  void markSaved(String uri) {
    final OpenDocument? document = documentByUri(uri);
    if (document == null) return;
    document
      ..dirty = false
      ..saving = false;
    notifyListeners();
  }

  void setSaving(String uri, bool value) {
    final OpenDocument? document = documentByUri(uri);
    if (document == null) return;
    document.saving = value;
    notifyListeners();
  }

  Future<void> writeDocument(String uri, String content) async {
    final OpenDocument? document = documentByUri(uri);
    if (document == null) return;
    if (document.loading) {
      _message = 'Aguarde o carregamento terminar antes de salvar.';
      notifyListeners();
      return;
    }
    setSaving(uri, true);
    try {
      await _repository.writeText(uri, content);
      _contentCache[uri] = content;
      markSaved(uri);
      _message = 'Salvo: ${document.entry.name}';
      notifyListeners();
    } catch (error, stack) {
      document.saving = false;
      AppErrorReporter.record(error, stack);
      _message = error.toString();
      notifyListeners();
    }
  }

  void closeDocument(String uri) {
    final int index = _documents.indexWhere(
      (OpenDocument item) => item.uri == uri,
    );
    if (index < 0) return;
    _documents.removeAt(index);
    if (_activeUri == uri) {
      if (_documents.isEmpty) {
        _activeUri = null;
      } else {
        _activeUri =
            _documents[index.clamp(0, _documents.length - 1).toInt()].uri;
      }
    }
    notifyListeners();
  }

  Future<WorkspaceEntry?> createFile(String name, {String? parentUri}) async {
    WorkspaceEntry? created;
    await _run(() async {
      final String parent = parentUri ?? _targetDirectoryUri();
      created = await _repository.createFile(parent, name.trim());
      await _loadDirectory(parent, expand: true);
      if (created != null) await openFile(created!);
    });
    return created;
  }

  Future<WorkspaceEntry?> createDirectory(
    String name, {
    String? parentUri,
  }) async {
    WorkspaceEntry? created;
    await _run(() async {
      final String parent = parentUri ?? _targetDirectoryUri();
      created = await _repository.createDirectory(parent, name.trim());
      await _loadDirectory(parent, expand: true);
      _selected = created;
    });
    return created;
  }

  Future<void> createWebProject(String name) async {
    await _run(() async {
      final String parent = _targetDirectoryUri();
      WorkspaceEntry? folder;
      try {
        folder = await _repository.createDirectory(parent, name.trim());
        final WorkspaceEntry html = await _repository.createFile(
          folder.uri,
          'index.html',
        );
        final WorkspaceEntry css = await _repository.createFile(
          folder.uri,
          'styles.css',
        );
        final WorkspaceEntry js = await _repository.createFile(
          folder.uri,
          'app.js',
        );
        await Future.wait(<Future<void>>[
          _repository.writeText(html.uri, _htmlTemplate(name.trim())),
          _repository.writeText(css.uri, _cssTemplate),
          _repository.writeText(js.uri, _jsTemplate),
        ]);
        await _loadDirectory(parent, expand: true);
        await _loadDirectory(folder.uri, expand: true);
        await openFile(html);
        _message = 'Projeto web criado com três arquivos.';
      } catch (_) {
        if (folder != null) {
          await _repository.delete(folder.uri);
          await _loadDirectory(parent, expand: true);
        }
        rethrow;
      }
    });
  }

  Future<void> renameEntry(WorkspaceEntry entry, String name) async {
    if (documentByUri(entry.uri) != null) {
      _message = 'Feche a aba “${entry.name}” antes de renomear.';
      notifyListeners();
      return;
    }
    await _run(() async {
      final WorkspaceEntry renamed = await _repository.rename(
        entry,
        name.trim(),
      );
      final String? parent = entry.parentUri;
      if (parent != null) await _loadDirectory(parent, expand: true);
      _selected = renamed;
    });
  }

  Future<void> deleteEntry(WorkspaceEntry entry) async {
    if (documentByUri(entry.uri) != null) {
      _message = 'Feche a aba “${entry.name}” antes de excluir.';
      notifyListeners();
      return;
    }
    await _run(() async {
      await _repository.delete(entry.uri);
      closeDocument(entry.uri);
      _children.remove(entry.uri);
      _expanded.remove(entry.uri);
      final String? parent = entry.parentUri;
      if (parent != null) await _loadDirectory(parent, expand: true);
      _selected = _root;
      _message = 'Removido: ${entry.name}';
    });
  }

  void copy(WorkspaceEntry entry, {bool cut = false}) {
    _clipboard = entry;
    _clipboardMode = cut ? ClipboardMode.cut : ClipboardMode.copy;
    _message = cut ? 'Pronto para mover.' : 'Pronto para copiar.';
    notifyListeners();
  }

  Future<void> paste({String? targetParentUri}) async {
    final WorkspaceEntry? source = _clipboard;
    final ClipboardMode? mode = _clipboardMode;
    if (source == null || mode == null) return;
    if (mode == ClipboardMode.cut && documentByUri(source.uri) != null) {
      _message = 'Feche a aba “${source.name}” antes de mover.';
      notifyListeners();
      return;
    }
    await _run(() async {
      final String target = targetParentUri ?? _targetDirectoryUri();
      if (target == source.uri) {
        throw StateError('Não é possível colar uma pasta dentro dela mesma.');
      }
      if (mode == ClipboardMode.cut) {
        await _repository.moveTo(source, target);
        if (source.parentUri != null) {
          await _loadDirectory(source.parentUri!, expand: true);
        }
        _clipboard = null;
        _clipboardMode = null;
      } else {
        await _repository.copyTo(source, target);
      }
      await _loadDirectory(target, expand: true);
      _message = mode == ClipboardMode.cut ? 'Item movido.' : 'Cópia criada.';
    });
  }

  Future<void> importFiles({String? targetParentUri}) async {
    await _run(() async {
      final String target = targetParentUri ?? _targetDirectoryUri();
      final List<WorkspaceEntry> files = await _repository.pickFiles();
      for (final WorkspaceEntry file in files) {
        await _repository.copyTo(file, target);
      }
      await _loadDirectory(target, expand: true);
      if (files.isNotEmpty)
        _message = '${files.length} arquivo(s) importado(s).';
    });
  }

  Future<List<SearchMatch>> search(
    String query, {
    bool caseSensitive = false,
  }) async {
    final WorkspaceEntry? workspace = _root;
    if (workspace == null || query.trim().isEmpty) return <SearchMatch>[];
    try {
      return await _repository.search(
        workspace.uri,
        query.trim(),
        caseSensitive: caseSensitive,
      );
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      _message = error.toString();
      notifyListeners();
      return <SearchMatch>[];
    }
  }

  Future<void> openSearchMatch(SearchMatch match) async {
    await _run(() async {
      final WorkspaceEntry? entry = await _repository.inspect(match.uri);
      if (entry != null) await openFile(entry);
    });
  }

  String _targetDirectoryUri() {
    final WorkspaceEntry? target = _selected;
    if (target?.isDirectory == true) return target!.uri;
    return target?.parentUri ??
        _root?.uri ??
        (throw StateError('Abra uma pasta.'));
  }

  void clearMessage() {
    _message = null;
    notifyListeners();
  }

  Future<void> _run(
    Future<void> Function() operation, {
    bool silent = false,
  }) async {
    _busy = true;
    if (!silent) _message = null;
    notifyListeners();
    try {
      await operation();
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      _message = error.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String> _readText(String uri) {
    final String? cached = _contentCache[uri];
    if (cached != null) return Future<String>.value(cached);

    final Future<String>? pending = _pendingReads[uri];
    if (pending != null) return pending;

    final Future<String> read = _repository.readText(uri);
    _pendingReads[uri] = read;
    return read.then(
      (String content) {
        _contentCache[uri] = content;
        _pendingReads.remove(uri);
        return content;
      },
      onError: (Object error, StackTrace stack) {
        _pendingReads.remove(uri);
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  static String _htmlTemplate(String name) =>
      '''<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$name</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <main>
    <h1>$name</h1>
    <p>Projeto criado no MV Code.</p>
  </main>
  <script src="app.js"></script>
</body>
</html>
''';

  static const String _cssTemplate = '''* { box-sizing: border-box; }
body { margin: 0; min-height: 100vh; display: grid; place-items: center;
  font: 16px system-ui; background: #111318; color: #f2f5f7; }
main { width: min(92%, 680px); padding: 32px; border: 1px solid #303640;
  border-radius: 16px; background: #181b22; }
h1 { color: #23a8f2; }
''';

  static const String _jsTemplate =
      '''const title = document.querySelector('h1');
title.addEventListener('click', () => {
  title.textContent = 'MV Code pronto!';
});
''';
}
