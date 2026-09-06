import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/highlight_core.dart' show Mode;
import 'package:highlight/languages/all.dart' show allLanguages;

import '../workspace/domain/workspace_entry.dart';

class EditorProblem {
  const EditorProblem({
    required this.line,
    required this.column,
    required this.severity,
    required this.message,
  });

  final int line;
  final int column;
  final int severity;
  final String message;

  bool get isError => severity == 8;
}

class FlutterCodeEditorView extends StatefulWidget {
  const FlutterCodeEditorView({
    required this.document,
    required this.options,
    required this.onChanged,
    required this.onSaveRequested,
    required this.onCursorChanged,
    required this.onProblemsChanged,
    required this.onQuickOpenRequested,
    required this.onCommandPaletteRequested,
    required this.onMessage,
    super.key,
  });

  final OpenDocument? document;
  final Map<String, Object> options;
  final void Function(String uri, String content) onChanged;
  final ValueChanged<String> onSaveRequested;
  final void Function(int line, int column) onCursorChanged;
  final ValueChanged<List<EditorProblem>> onProblemsChanged;
  final VoidCallback onQuickOpenRequested;
  final VoidCallback onCommandPaletteRequested;
  final ValueChanged<String> onMessage;

  @override
  State<FlutterCodeEditorView> createState() => FlutterCodeEditorViewState();
}

class FlutterCodeEditorViewState extends State<FlutterCodeEditorView> {
  CodeController? _controller;
  UndoHistoryController? _undoController;
  FocusNode? _focusNode;
  Timer? _analysisTimer;
  String? _uri;
  String _lastText = '';
  int _lastLine = 1;
  int _lastColumn = 1;
  bool _syncingFromModel = false;

  CodeController? get controller => _controller;

  @override
  void initState() {
    super.initState();
    _configureDocument(widget.document);
  }

  @override
  void didUpdateWidget(covariant FlutterCodeEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final OpenDocument? oldDocument = oldWidget.document;
    final OpenDocument? newDocument = widget.document;

    if (oldDocument?.uri != newDocument?.uri) {
      _configureDocument(newDocument);
      return;
    }

    if (newDocument == null) return;

    final int oldTabSize = _optionInt(oldWidget.options, 'tabSize', 2);
    final int newTabSize = _optionInt(widget.options, 'tabSize', 2);
    if (oldTabSize != newTabSize) {
      _recreateControllerForTabSize(newDocument);
      return;
    }

    if (oldDocument?.initialContent != newDocument.initialContent ||
        oldDocument?.loading != newDocument.loading) {
      _syncContentFromDocument(newDocument);
    }
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _disposeEditorObjects();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OpenDocument? document = widget.document;
    final CodeController? codeController = _controller;
    final UndoHistoryController? undoController = _undoController;
    final FocusNode? focusNode = _focusNode;

    if (document == null) return const SizedBox.shrink();

    if (document.loading || codeController == null || focusNode == null) {
      return const Center(
        child: SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color background =
        dark ? const Color(0xFF111318) : const Color(0xFFFAFBFC);
    final double fontSize = _optionDouble(widget.options, 'fontSize', 14);
    final bool wrap = _optionBool(widget.options, 'wordWrap', false);
    final bool lineNumbers = _optionBool(widget.options, 'lineNumbers', true);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          final String? target = _uri;
          if (target != null) widget.onSaveRequested(target);
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): find,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            widget.onQuickOpenRequested,
        const SingleActivator(
          LogicalKeyboardKey.keyP,
          control: true,
          shift: true,
        ): widget.onCommandPaletteRequested,
      },
      child: ColoredBox(
        color: background,
        child: CodeTheme(
          data: CodeThemeData(
            styles: dark ? atomOneDarkTheme : githubTheme,
          ),
          child: CodeField(
            controller: codeController,
            undoController: undoController,
            focusNode: focusNode,
            expands: true,
            wrap: wrap,
            background: background,
            cursorColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 24),
            gutterStyle: GutterStyle(
              width: lineNumbers ? 62 : 26,
              margin: 8,
              showErrors: true,
              showFoldingHandles: false,
              showLineNumbers: lineNumbers,
              background: background,
              textStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
                fontSize: fontSize - 1,
                height: 1.5,
              ),
            ),
            textStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  void _configureDocument(OpenDocument? document) {
    _analysisTimer?.cancel();
    _disposeEditorObjects();

    _uri = document?.uri;
    _lastText = document?.initialContent ?? '';
    _lastLine = 1;
    _lastColumn = 1;

    if (document == null) return;

    _focusNode = FocusNode(debugLabel: 'MVCodeEditor');
    _undoController = UndoHistoryController();
    _controller = CodeController(
      text: document.initialContent,
      language: languageForFile(document.entry.name),
      params: EditorParams(
        tabSpaces: _optionInt(widget.options, 'tabSize', 2),
      ),
    )..addListener(_onControllerChanged);

    if (!document.loading) {
      _scheduleAnalysis();
    }
  }

  void _recreateControllerForTabSize(OpenDocument document) {
    final CodeController? current = _controller;
    final String text = current?.fullText ?? document.initialContent;
    final TextSelection selection =
        current?.selection ?? const TextSelection.collapsed(offset: 0);

    _analysisTimer?.cancel();
    _disposeEditorObjects();

    _focusNode = FocusNode(debugLabel: 'MVCodeEditor');
    _undoController = UndoHistoryController();
    _uri = document.uri;
    _lastText = text;
    _controller = CodeController(
      text: text,
      language: languageForFile(document.entry.name),
      params: EditorParams(
        tabSpaces: _optionInt(widget.options, 'tabSize', 2),
      ),
    )..addListener(_onControllerChanged);

    final int safeOffset = selection.baseOffset.clamp(0, text.length).toInt();
    _controller!.selection = TextSelection.collapsed(offset: safeOffset);
    _scheduleAnalysis();
    setState(() {});
  }

  void _syncContentFromDocument(OpenDocument document) {
    final CodeController? codeController = _controller;
    if (codeController == null) {
      _configureDocument(document);
      setState(() {});
      return;
    }

    if (codeController.fullText == document.initialContent) return;

    _syncingFromModel = true;
    try {
      final int oldOffset =
          codeController.selection.baseOffset.clamp(0, document.initialContent.length).toInt();
      codeController.fullText = document.initialContent;
      codeController.selection = TextSelection.collapsed(offset: oldOffset);
      _lastText = document.initialContent;
    } finally {
      _syncingFromModel = false;
    }
    _scheduleAnalysis();
  }

  void _disposeEditorObjects() {
    final CodeController? codeController = _controller;
    if (codeController != null) {
      codeController.removeListener(_onControllerChanged);
      codeController.dispose();
    }
    _undoController?.dispose();
    _focusNode?.dispose();
    _controller = null;
    _undoController = null;
    _focusNode = null;
  }

  void _onControllerChanged() {
    final CodeController? codeController = _controller;
    final String? target = _uri;
    if (codeController == null || target == null || !mounted) return;

    final String text = codeController.fullText;
    if (!_syncingFromModel && text != _lastText) {
      _lastText = text;
      widget.onChanged(target, text);
      _scheduleAnalysis();
    }

    _emitCursor(codeController);
  }

  void _emitCursor(CodeController codeController) {
    final int offset =
        codeController.selection.extentOffset.clamp(0, codeController.fullText.length).toInt();
    final String before = codeController.fullText.substring(0, offset);
    final int line = '\n'.allMatches(before).length + 1;
    final int lastBreak = before.lastIndexOf('\n');
    final int column = offset - lastBreak;

    if (line == _lastLine && column == _lastColumn) return;
    _lastLine = line;
    _lastColumn = column;
    widget.onCursorChanged(line, column);
  }

  void _scheduleAnalysis() {
    _analysisTimer?.cancel();
    _analysisTimer = Timer(const Duration(milliseconds: 280), _analyze);
  }

  Future<void> _analyze() async {
    final CodeController? codeController = _controller;
    if (codeController == null || !mounted) return;

    try {
      await codeController.analyzeCode();
      if (!mounted || codeController != _controller) return;

      final List<EditorProblem> problems = codeController.analysisResult.issues
          .map(
            (Issue issue) => EditorProblem(
              line: issue.line < 1 ? 1 : issue.line,
              column: 1,
              severity: switch (issue.type) {
                IssueType.error => 8,
                IssueType.warning => 4,
                IssueType.info => 2,
              },
              message: issue.message,
            ),
          )
          .toList(growable: false);
      widget.onProblemsChanged(problems);
    } catch (error) {
      if (mounted) {
        widget.onMessage('Falha ao analisar o arquivo: $error');
      }
    }
  }

  String content([String? uri]) {
    if (uri != null && uri != _uri) return '';
    return _controller?.fullText ?? '';
  }

  Future<void> find() async {
    _focusNode?.requestFocus();
    _controller?.showSearch();
  }

  Future<void> replace() async {
    final CodeController? codeController = _controller;
    if (codeController == null || !mounted) return;

    final TextEditingController search = TextEditingController();
    final TextEditingController replacement = TextEditingController();

    final _ReplaceAction? action = await showDialog<_ReplaceAction>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Substituir no arquivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: search,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Localizar'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replacement,
              decoration: const InputDecoration(labelText: 'Substituir por'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _ReplaceAction.one),
            child: const Text('Uma'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _ReplaceAction.all),
            child: const Text('Todas'),
          ),
        ],
      ),
    );

    final String needle = search.text;
    final String replacementText = replacement.text;
    search.dispose();
    replacement.dispose();

    if (action == null || needle.isEmpty || !mounted) return;

    final String source = codeController.fullText;
    String updated = source;

    if (action == _ReplaceAction.all) {
      updated = source.replaceAll(needle, replacementText);
    } else {
      final int start =
          codeController.selection.extentOffset.clamp(0, source.length).toInt();
      int index = source.indexOf(needle, start);
      if (index < 0 && start > 0) index = source.indexOf(needle);
      if (index >= 0) {
        updated = source.replaceRange(
          index,
          index + needle.length,
          replacementText,
        );
      }
    }

    if (updated == source) {
      widget.onMessage('Texto não encontrado.');
      return;
    }

    codeController.fullText = updated;
    _focusNode?.requestFocus();
  }

  Future<void> undo() async {
    _undoController?.undo();
    _focusNode?.requestFocus();
  }

  Future<void> redo() async {
    _undoController?.redo();
    _focusNode?.requestFocus();
  }

  Future<void> format() async {
    final CodeController? codeController = _controller;
    final OpenDocument? document = widget.document;
    if (codeController == null || document == null) return;

    final String source = codeController.fullText;
    String formatted;

    if (document.entry.extension == 'json') {
      try {
        final Object? decoded = jsonDecode(source);
        formatted = const JsonEncoder.withIndent('  ').convert(decoded);
        if (source.endsWith('\n')) formatted = '$formatted\n';
      } on FormatException catch (error) {
        widget.onMessage('JSON inválido: ${error.message}');
        return;
      }
    } else {
      formatted = source
          .split('\n')
          .map((String line) => line.replaceFirst(RegExp(r'[ \t]+$'), ''))
          .join('\n');
    }

    if (formatted == source) {
      widget.onMessage('Nenhuma alteração de formatação necessária.');
      return;
    }

    final int offset =
        codeController.selection.extentOffset.clamp(0, formatted.length).toInt();
    codeController.fullText = formatted;
    codeController.selection = TextSelection.collapsed(offset: offset);
    _focusNode?.requestFocus();
  }

  void insert(String value) {
    final CodeController? codeController = _controller;
    if (codeController == null) return;
    _focusNode?.requestFocus();

    final String insertion = value == '\t'
        ? List<String>.filled(
            _optionInt(widget.options, 'tabSize', 2),
            ' ',
          ).join()
        : value;
    codeController.insertStr(insertion);
  }

  void command(String value) {
    final CodeController? codeController = _controller;
    if (codeController == null) return;

    switch (value) {
      case 'escape':
        _focusNode?.unfocus();
      case 'cursorLeft':
        _moveCursorHorizontal(-1);
      case 'cursorRight':
        _moveCursorHorizontal(1);
      case 'cursorUp':
        _moveCursorVertical(-1);
      case 'cursorDown':
        _moveCursorVertical(1);
      default:
        break;
    }
  }

  Future<void> goTo(int line, [int column = 1]) async {
    final CodeController? codeController = _controller;
    if (codeController == null) return;

    final String text = codeController.fullText;
    final List<String> lines = text.split('\n');
    if (lines.isEmpty) return;

    final int safeLine = line.clamp(1, lines.length).toInt();
    final int safeColumn =
        column.clamp(1, lines[safeLine - 1].length + 1).toInt();

    int offset = 0;
    for (int index = 0; index < safeLine - 1; index++) {
      offset += lines[index].length + 1;
    }
    offset += safeColumn - 1;

    codeController.selection = TextSelection.collapsed(offset: offset);
    _focusNode?.requestFocus();
  }

  void _moveCursorHorizontal(int delta) {
    final CodeController? codeController = _controller;
    if (codeController == null) return;
    final int current = codeController.selection.extentOffset;
    final int target =
        (current + delta).clamp(0, codeController.fullText.length).toInt();
    codeController.selection = TextSelection.collapsed(offset: target);
    _focusNode?.requestFocus();
  }

  void _moveCursorVertical(int delta) {
    final CodeController? codeController = _controller;
    if (codeController == null) return;

    final int offset =
        codeController.selection.extentOffset.clamp(0, codeController.fullText.length).toInt();
    final String before = codeController.fullText.substring(0, offset);
    final int currentLine = '\n'.allMatches(before).length + 1;
    final int lastBreak = before.lastIndexOf('\n');
    final int currentColumn = offset - lastBreak;

    goTo(currentLine + delta, currentColumn);
  }

  static Mode? languageForFile(String name) {
    final String lower = name.toLowerCase();

    if (lower == 'dockerfile') return allLanguages['dockerfile'];
    if (lower == 'makefile') return allLanguages['makefile'];

    final String extension =
        lower.contains('.') ? lower.split('.').last : '';

    final String? languageId = <String, String>{
      'html': 'xml',
      'htm': 'xml',
      'xml': 'xml',
      'svg': 'xml',
      'css': 'css',
      'scss': 'scss',
      'less': 'less',
      'js': 'javascript',
      'mjs': 'javascript',
      'cjs': 'javascript',
      'jsx': 'javascript',
      'ts': 'typescript',
      'tsx': 'typescript',
      'json': 'json',
      'jsonc': 'json',
      'md': 'markdown',
      'dart': 'dart',
      'kt': 'kotlin',
      'kts': 'kotlin',
      'java': 'java',
      'py': 'python',
      'rb': 'ruby',
      'rs': 'rust',
      'go': 'go',
      'c': 'cpp',
      'h': 'cpp',
      'cpp': 'cpp',
      'cc': 'cpp',
      'hpp': 'cpp',
      'cs': 'cs',
      'php': 'php',
      'sh': 'bash',
      'bash': 'bash',
      'yaml': 'yaml',
      'yml': 'yaml',
      'sql': 'sql',
      'gradle': 'gradle',
      'ini': 'ini',
      'toml': 'ini',
    }[extension];

    return languageId == null ? null : allLanguages[languageId];
  }

  static bool _optionBool(
    Map<String, Object> options,
    String key,
    bool fallback,
  ) =>
      options[key] is bool ? options[key]! as bool : fallback;

  static int _optionInt(
    Map<String, Object> options,
    String key,
    int fallback,
  ) =>
      options[key] is num ? (options[key]! as num).toInt() : fallback;

  static double _optionDouble(
    Map<String, Object> options,
    String key,
    double fallback,
  ) =>
      options[key] is num ? (options[key]! as num).toDouble() : fallback;
}

enum _ReplaceAction { one, all }
