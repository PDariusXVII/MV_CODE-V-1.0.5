import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../editor/flutter_code_editor_view.dart';
import '../../editor/symbol_bar.dart';
import '../../preview/preview_screen.dart';
import '../../search/workspace_search_panel.dart';
import '../../settings/settings_controller.dart';
import '../../settings/settings_panel.dart';
import '../domain/workspace_entry.dart';
import 'file_browser.dart';
import 'workspace_controller.dart';

enum _SideView { explorer, search, problems, settings }

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final GlobalKey<FlutterCodeEditorViewState> _editorKey =
      GlobalKey<FlutterCodeEditorViewState>();
  _SideView _sideView = _SideView.explorer;
  final Map<String, Timer> _autoSaveTimers = <String, Timer>{};
  int _line = 1;
  int _column = 1;
  List<EditorProblem> _problems = <EditorProblem>[];
  bool _bottomPanel = false;
  String? _shownMessage;
  final List<String> _output = <String>[
    'MV Code iniciado em modo local.',
    'Nenhum serviço externo ou telemetria está ativo.',
  ];

  @override
  void dispose() {
    for (final Timer timer in _autoSaveTimers.values) {
      timer.cancel();
    }
    _autoSaveTimers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceController workspace = context.watch<WorkspaceController>();
    final SettingsController settings = context.watch<SettingsController>();
    _showControllerMessage(workspace);
    final bool hasUnsaved = workspace.documents.any(
      (OpenDocument document) => document.dirty,
    );

    return PopScope<Object?>(
      canPop: !hasUnsaved,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _confirmExit();
      },
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 760;
          return Scaffold(
            appBar: _buildAppBar(context, workspace, wide),
            body: SafeArea(
              top: false,
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        if (wide)
                          _ActivityRail(
                            selected: _sideView,
                            onSelected: _selectSideView,
                          ),
                        if (wide)
                          SizedBox(
                            width: constraints.maxWidth >= 1100 ? 300 : 260,
                            child: _SidePanel(
                              view: _sideView,
                              onSearchResult: _openSearchResult,
                              problems: _problems,
                              onProblem: _goToProblem,
                            ),
                          ),
                        Expanded(
                          child: _EditorArea(
                            editorKey: _editorKey,
                            workspace: workspace,
                            settings: settings,
                            line: _line,
                            column: _column,
                            problems: _problems,
                            bottomPanel: _bottomPanel,
                            output: _output,
                            onChanged: _onEditorChanged,
                            onSave: _saveDocument,
                            onClose: _closeDocument,
                            onCursor: (int line, int column) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(() {
                                  _line = line;
                                  _column = column;
                                });
                              });
                            },
                            onProblems: (List<EditorProblem> value) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(() => _problems = value);
                              });
                            },
                            onQuickOpen: _showQuickOpen,
                            onPalette: _showCommandPalette,
                            onMessage: _addOutput,
                            onTogglePanel: () =>
                                setState(() => _bottomPanel = !_bottomPanel),
                            onProblem: _goToProblem,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!wide)
                    _MobileNavigation(
                      selected: _sideView,
                      onSelected: _openMobilePanel,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WorkspaceController workspace,
    bool wide,
  ) {
    final OpenDocument? document = workspace.activeDocument;
    return AppBar(
      toolbarHeight: 48,
      leadingWidth: 48,
      leading: Padding(
        padding: const EdgeInsets.all(9),
        child: Image.asset('assets/app_icon.png'),
      ),
      titleSpacing: 2,
      title: Row(
        children: <Widget>[
          const Text(
            'MV Code',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (workspace.root != null) ...<Widget>[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '— ${workspace.root!.name}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        if (workspace.busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Salvar (Ctrl+S)',
          onPressed: document == null
              ? null
              : () => _saveDocument(document.uri),
          icon: Icon(
            document?.dirty == true ? Icons.save : Icons.save_outlined,
            size: 21,
          ),
        ),
        IconButton(
          tooltip: 'Localizar (Ctrl+F)',
          onPressed: document == null ? null : _editorKey.currentState?.find,
          icon: const Icon(Icons.find_in_page_outlined, size: 21),
        ),
        IconButton(
          tooltip: 'Pré-visualizar HTML',
          onPressed:
              document?.entry.extension == 'html' ||
                  document?.entry.extension == 'htm'
              ? _openPreview
              : null,
          icon: const Icon(Icons.play_arrow_rounded, size: 24),
        ),
        if (!wide)
          IconButton(
            tooltip: 'Comandos',
            onPressed: _showCommandPalette,
            icon: const Icon(Icons.more_vert),
          ),
      ],
    );
  }

  void _selectSideView(_SideView value) => setState(() => _sideView = value);

  void _openMobilePanel(_SideView value) {
    setState(() => _sideView = value);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => FractionallySizedBox(
        heightFactor: 0.74,
        child: _SidePanel(
          view: value,
          onSearchResult: (SearchMatch match) {
            Navigator.pop(sheetContext);
            _openSearchResult(match);
          },
          problems: _problems,
          onProblem: (EditorProblem problem) {
            Navigator.pop(sheetContext);
            _goToProblem(problem);
          },
        ),
      ),
    );
  }

  void _onEditorChanged(String uri, String content) {
    final WorkspaceController workspace = context.read<WorkspaceController>();
    workspace.updateDocumentContent(uri, content);

    if (!context.read<SettingsController>().autoSave) return;
    _autoSaveTimers.remove(uri)?.cancel();
    _autoSaveTimers[uri] = Timer(const Duration(milliseconds: 1200), () {
      _autoSaveTimers.remove(uri);
      _saveDocument(uri);
    });
  }

  Future<void> _saveDocument(String uri) async {
    final WorkspaceController workspace = context.read<WorkspaceController>();
    final OpenDocument? document = workspace.documentByUri(uri);
    if (document == null || document.loading) return;
    await workspace.writeDocument(uri, document.initialContent);
  }

  Future<void> _saveAll() async {
    final WorkspaceController workspace = context.read<WorkspaceController>();
    final List<OpenDocument> dirty = workspace.documents
        .where((OpenDocument document) => document.dirty)
        .toList();
    for (final OpenDocument document in dirty) {
      await _saveDocument(document.uri);
    }
  }

  Future<void> _confirmExit() async {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Sair do MV Code?'),
        content: const Text(
          'Existem arquivos com alterações ainda não gravadas.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Salvar tudo'),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      await _saveAll();
      if (!mounted) return;
      final bool stillDirty = context.read<WorkspaceController>().documents.any(
        (OpenDocument document) => document.dirty,
      );
      if (stillDirty) return;
      await SystemNavigator.pop();
    } else if (choice == 'discard') {
      await SystemNavigator.pop();
    }
  }

  Future<void> _closeDocument(OpenDocument document) async {
    if (document.dirty) {
      final String? choice = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text('Salvar ${document.entry.name}?'),
          content: const Text(
            'Existem alterações ainda não gravadas no dispositivo.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'discard'),
              child: const Text('Descartar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'save'),
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == 'save') {
        await _saveDocument(document.uri);
        if (!mounted) return;
        final bool saveFailed =
            context
                .read<WorkspaceController>()
                .documentByUri(document.uri)
                ?.dirty ==
            true;
        if (saveFailed) return;
      }
    }
    _autoSaveTimers.remove(document.uri)?.cancel();
    if (!mounted) return;
    context.read<WorkspaceController>().closeDocument(document.uri);
  }

  Future<void> _openSearchResult(SearchMatch match) async {
    await context.read<WorkspaceController>().openSearchMatch(match);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _editorKey.currentState?.goTo(match.line, match.column);
  }

  void _goToProblem(EditorProblem problem) {
    _editorKey.currentState?.goTo(problem.line, problem.column);
  }

  Future<void> _openPreview() async {
    final WorkspaceController workspace = context.read<WorkspaceController>();
    final OpenDocument? active = workspace.activeDocument;
    if (active == null || active.loading) return;

    String html = active.initialContent;
    for (final OpenDocument document in workspace.documents) {
      if (document.uri == active.uri || document.loading) continue;
      final String content = document.initialContent;
      final String name = RegExp.escape(document.entry.name);
      if (document.entry.extension == 'css') {
        html = html.replaceAll(
          RegExp(
            '<link[^>]+href=["\'][^"\']*$name["\'][^>]*>',
            caseSensitive: false,
          ),
          '<style>\n$content\n</style>',
        );
      } else if (document.entry.extension == 'js') {
        html = html.replaceAll(
          RegExp(
            '<script[^>]+src=["\'][^"\']*$name["\'][^>]*>\\s*</script>',
            caseSensitive: false,
          ),
          '<script>\n$content\n</script>',
        );
      }
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PreviewScreen(title: active.entry.name, html: html),
      ),
    );
  }

  Future<void> _showQuickOpen() async {
    final WorkspaceController workspace = context.read<WorkspaceController>();
    final List<WorkspaceEntry> files = workspace.loadedFiles;
    final WorkspaceEntry? selected = await showSearch<WorkspaceEntry?>(
      context: context,
      delegate: _QuickOpenDelegate(files),
    );
    if (selected != null) await workspace.openFile(selected);
  }

  Future<void> _showCommandPalette() async {
    final List<_Command> commands = <_Command>[
      _Command(
        'Abrir pasta',
        Icons.folder_open,
        () => context.read<WorkspaceController>().pickWorkspace(),
      ),
      _Command('Novo arquivo', Icons.note_add_outlined, _newFile),
      _Command('Nova pasta', Icons.create_new_folder_outlined, _newFolder),
      _Command('Novo projeto web', Icons.web_outlined, _newWebProject),
      _Command('Salvar arquivo', Icons.save_outlined, () async {
        final String? uri = context
            .read<WorkspaceController>()
            .activeDocument
            ?.uri;
        if (uri != null) await _saveDocument(uri);
      }),
      _Command('Localizar no arquivo', Icons.find_in_page_outlined, () async {
        await _editorKey.currentState?.find();
      }),
      _Command('Substituir no arquivo', Icons.find_replace, () async {
        await _editorKey.currentState?.replace();
      }),
      _Command('Formatar documento', Icons.auto_fix_high, () async {
        await _editorKey.currentState?.format();
      }),
      _Command('Desfazer', Icons.undo, () async {
        await _editorKey.currentState?.undo();
      }),
      _Command('Refazer', Icons.redo, () async {
        await _editorKey.currentState?.redo();
      }),
      _Command('Abrir arquivo rápido', Icons.bolt, _showQuickOpen),
      _Command(
        'Alternar painel de problemas',
        Icons.warning_amber,
        () => setState(() => _bottomPanel = !_bottomPanel),
      ),
    ];
    final _Command? command = await showSearch<_Command?>(
      context: context,
      delegate: _CommandDelegate(commands),
    );
    command?.run();
  }

  Future<void> _newFile() async {
    final String? name = await _inputDialog('Novo arquivo', 'arquivo.dart');
    if (name != null && mounted) {
      await context.read<WorkspaceController>().createFile(name);
    }
  }

  Future<void> _newFolder() async {
    final String? name = await _inputDialog('Nova pasta', 'src');
    if (name != null && mounted) {
      await context.read<WorkspaceController>().createDirectory(name);
    }
  }

  Future<void> _newWebProject() async {
    final String? name = await _inputDialog('Novo projeto web', 'meu-site');
    if (name != null && mounted) {
      await context.read<WorkspaceController>().createWebProject(name);
    }
  }

  Future<String?> _inputDialog(String title, String hint) async {
    final TextEditingController input = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (String value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(dialogContext, value.trim());
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, input.text.trim());
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    input.dispose();
    return result;
  }

  void _addOutput(String message) {
    setState(() {
      _output.add(message);
      if (_output.length > 200) _output.removeAt(0);
    });
  }

  void _showControllerMessage(WorkspaceController controller) {
    final String? message = controller.message;
    if (message == null || message == _shownMessage) return;
    _shownMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      controller.clearMessage();
      _shownMessage = null;
    });
  }
}

class _ActivityRail extends StatelessWidget {
  const _ActivityRail({required this.selected, required this.onSelected});

  final _SideView selected;
  final ValueChanged<_SideView> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: <Widget>[
          _RailButton(
            value: _SideView.explorer,
            selected: selected,
            icon: Icons.file_copy_outlined,
            tooltip: 'Explorer',
            onTap: onSelected,
          ),
          _RailButton(
            value: _SideView.search,
            selected: selected,
            icon: Icons.search,
            tooltip: 'Pesquisar',
            onTap: onSelected,
          ),
          _RailButton(
            value: _SideView.problems,
            selected: selected,
            icon: Icons.warning_amber_outlined,
            tooltip: 'Problemas',
            onTap: onSelected,
          ),
          const Spacer(),
          _RailButton(
            value: _SideView.settings,
            selected: selected,
            icon: Icons.settings_outlined,
            tooltip: 'Configurações',
            onTap: onSelected,
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.value,
    required this.selected,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final _SideView value;
  final _SideView selected;
  final IconData icon;
  final String tooltip;
  final ValueChanged<_SideView> onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = value == selected;
    return SizedBox(
      height: 48,
      width: 48,
      child: IconButton(
        tooltip: tooltip,
        onPressed: () => onTap(value),
        icon: Icon(
          icon,
          color: active ? Theme.of(context).colorScheme.primary : null,
        ),
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          side: active
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 0,
                  strokeAlign: BorderSide.strokeAlignOutside,
                )
              : null,
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.view,
    required this.onSearchResult,
    required this.problems,
    required this.onProblem,
  });

  final _SideView view;
  final ValueChanged<SearchMatch> onSearchResult;
  final List<EditorProblem> problems;
  final ValueChanged<EditorProblem> onProblem;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: switch (view) {
        _SideView.explorer => const FileBrowser(),
        _SideView.search => WorkspaceSearchPanel(onOpenResult: onSearchResult),
        _SideView.problems => _ProblemsList(
          problems: problems,
          onProblem: onProblem,
        ),
        _SideView.settings => const SettingsPanel(),
      },
    );
  }
}

class _EditorArea extends StatelessWidget {
  const _EditorArea({
    required this.editorKey,
    required this.workspace,
    required this.settings,
    required this.line,
    required this.column,
    required this.problems,
    required this.bottomPanel,
    required this.output,
    required this.onChanged,
    required this.onSave,
    required this.onClose,
    required this.onCursor,
    required this.onProblems,
    required this.onQuickOpen,
    required this.onPalette,
    required this.onMessage,
    required this.onTogglePanel,
    required this.onProblem,
  });

  final GlobalKey<FlutterCodeEditorViewState> editorKey;
  final WorkspaceController workspace;
  final SettingsController settings;
  final int line;
  final int column;
  final List<EditorProblem> problems;
  final bool bottomPanel;
  final List<String> output;
  final void Function(String uri, String content) onChanged;
  final ValueChanged<String> onSave;
  final ValueChanged<OpenDocument> onClose;
  final void Function(int, int) onCursor;
  final ValueChanged<List<EditorProblem>> onProblems;
  final VoidCallback onQuickOpen;
  final VoidCallback onPalette;
  final ValueChanged<String> onMessage;
  final VoidCallback onTogglePanel;
  final ValueChanged<EditorProblem> onProblem;

  @override
  Widget build(BuildContext context) {
    final OpenDocument? active = workspace.activeDocument;
    return Column(
      children: <Widget>[
        if (workspace.documents.isNotEmpty)
          _EditorTabs(workspace: workspace, onClose: onClose),
        Expanded(
          child: active == null
              ? _Welcome(workspace: workspace)
              : FlutterCodeEditorView(
                  key: editorKey,
                  document: active,
                  options: settings.editorOptions,
                  onChanged: onChanged,
                  onSaveRequested: onSave,
                  onCursorChanged: onCursor,
                  onProblemsChanged: onProblems,
                  onQuickOpenRequested: onQuickOpen,
                  onCommandPaletteRequested: onPalette,
                  onMessage: onMessage,
                ),
        ),
        if (active != null)
          SymbolBar(
            onInsert: (String value) => editorKey.currentState?.insert(value),
            onCommand: (String value) => editorKey.currentState?.command(value),
          ),
        if (bottomPanel)
          _BottomPanel(
            problems: problems,
            output: output,
            onProblem: onProblem,
            onClose: onTogglePanel,
          ),
        _StatusBar(
          active: active,
          line: line,
          column: column,
          problems: problems,
          onPanel: onTogglePanel,
        ),
      ],
    );
  }
}

class _EditorTabs extends StatelessWidget {
  const _EditorTabs({required this.workspace, required this.onClose});

  final WorkspaceController workspace;
  final ValueChanged<OpenDocument> onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: workspace.documents.length,
        itemBuilder: (BuildContext context, int index) {
          final OpenDocument document = workspace.documents[index];
          final bool active = workspace.activeDocument?.uri == document.uri;
          return Material(
            color: active
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surfaceContainer,
            child: InkWell(
              onTap: () => workspace.activate(document.uri),
              child: Container(
                constraints: const BoxConstraints(minWidth: 110, maxWidth: 210),
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Theme.of(context).dividerColor),
                    top: BorderSide(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      entryIcon(document.entry),
                      size: 16,
                      color: entryColor(context, document.entry),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        document.entry.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: IconButton(
                        tooltip: 'Fechar',
                        padding: EdgeInsets.zero,
                        onPressed: () => onClose(document),
                        icon: document.saving
                            ? const SizedBox.square(
                                dimension: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                ),
                              )
                            : Icon(
                                document.dirty ? Icons.circle : Icons.close,
                                size: document.dirty ? 9 : 16,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.workspace});

  final WorkspaceController workspace;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: <Widget>[
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    'MV',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'MV Code',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Editor profissional para trabalhar diretamente nos seus arquivos Android.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: workspace.pickWorkspace,
                    icon: const Icon(Icons.folder_open),
                    label: Text(
                      workspace.hasWorkspace ? 'Trocar pasta' : 'Abrir pasta',
                    ),
                  ),
                  if (workspace.hasWorkspace)
                    OutlinedButton.icon(
                      onPressed: () =>
                          workspace.createWebProject('meu-projeto'),
                      icon: const Icon(Icons.web_outlined),
                      label: const Text('Projeto web'),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              const Wrap(
                spacing: 18,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  _Feature(
                    icon: Icons.account_tree_outlined,
                    label: 'Pastas hierárquicas',
                  ),
                  _Feature(
                    icon: Icons.find_replace,
                    label: 'Busca e substituição',
                  ),
                  _Feature(icon: Icons.lock_outline, label: '100% local'),
                  _Feature(
                    icon: Icons.keyboard_alt_outlined,
                    label: 'Atalhos profissionais',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 17), label: Text(label));
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.active,
    required this.line,
    required this.column,
    required this.problems,
    required this.onPanel,
  });
  final OpenDocument? active;
  final int line;
  final int column;
  final List<EditorProblem> problems;
  final VoidCallback onPanel;

  @override
  Widget build(BuildContext context) {
    final int errors = problems
        .where((EditorProblem item) => item.isError)
        .length;
    final int warnings = problems.length - errors;
    return Container(
      height: 25,
      color: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.shield_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          const Text(
            'Local',
            style: TextStyle(color: Colors.white, fontSize: 11.5),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: onPanel,
            child: Row(
              children: <Widget>[
                const Icon(Icons.close, size: 13, color: Colors.white),
                Text(
                  ' $errors  ',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                ),
                const Icon(Icons.warning_amber, size: 13, color: Colors.white),
                Text(
                  ' $warnings',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (active != null) ...<Widget>[
            Text(
              'Ln $line, Col $column',
              style: const TextStyle(color: Colors.white, fontSize: 11.5),
            ),
            const SizedBox(width: 14),
            Text(
              (active!.entry.extension.isEmpty
                  ? 'TEXT'
                  : active!.entry.extension.toUpperCase()),
              style: const TextStyle(color: Colors.white, fontSize: 11.5),
            ),
            const SizedBox(width: 10),
            const Text(
              'UTF-8',
              style: TextStyle(color: Colors.white, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.problems,
    required this.output,
    required this.onProblem,
    required this.onClose,
  });
  final List<EditorProblem> problems;
  final List<String> output;
  final ValueChanged<EditorProblem> onProblem;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: <Widget>[
                      Tab(text: 'PROBLEMAS'),
                      Tab(text: 'SAÍDA'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _ProblemsList(problems: problems, onProblem: onProblem),
                  ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: output.length,
                    itemBuilder: (_, int index) => Text(
                      output[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemsList extends StatelessWidget {
  const _ProblemsList({required this.problems, required this.onProblem});
  final List<EditorProblem> problems;
  final ValueChanged<EditorProblem> onProblem;
  @override
  Widget build(BuildContext context) {
    if (problems.isEmpty) {
      return const Center(child: Text('Nenhum problema detectado.'));
    }
    return ListView.builder(
      itemCount: problems.length,
      itemBuilder: (_, int index) {
        final EditorProblem problem = problems[index];
        return ListTile(
          dense: true,
          leading: Icon(
            problem.isError ? Icons.error_outline : Icons.warning_amber,
            size: 18,
            color: problem.isError ? Colors.redAccent : Colors.amber,
          ),
          title: Text(
            problem.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Text(
            '${problem.line}:${problem.column}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          onTap: () => onProblem(problem),
        );
      },
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.selected, required this.onSelected});
  final _SideView selected;
  final ValueChanged<_SideView> onSelected;
  @override
  Widget build(BuildContext context) => NavigationBar(
    height: 58,
    selectedIndex: _SideView.values.indexOf(selected),
    onDestinationSelected: (int index) => onSelected(_SideView.values[index]),
    destinations: const <NavigationDestination>[
      NavigationDestination(
        icon: Icon(Icons.file_copy_outlined),
        label: 'Arquivos',
      ),
      NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
      NavigationDestination(
        icon: Icon(Icons.warning_amber_outlined),
        label: 'Problemas',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        label: 'Ajustes',
      ),
    ],
  );
}

class _Command {
  const _Command(this.label, this.icon, this.run);
  final String label;
  final IconData icon;
  final FutureOr<void> Function() run;
}

class _CommandDelegate extends SearchDelegate<_Command?> {
  _CommandDelegate(this.commands)
    : super(searchFieldLabel: 'Digite um comando');
  final List<_Command> commands;
  @override
  List<Widget>? buildActions(BuildContext context) => <Widget>[
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );
  @override
  Widget buildResults(BuildContext context) => _list(context);
  @override
  Widget buildSuggestions(BuildContext context) => _list(context);
  Widget _list(BuildContext context) {
    final String needle = query.toLowerCase();
    final List<_Command> visible = commands
        .where((_Command item) => item.label.toLowerCase().contains(needle))
        .toList();
    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (_, int index) {
        final _Command command = visible[index];
        return ListTile(
          leading: Icon(command.icon),
          title: Text(command.label),
          onTap: () => close(context, command),
        );
      },
    );
  }
}

class _QuickOpenDelegate extends SearchDelegate<WorkspaceEntry?> {
  _QuickOpenDelegate(this.files)
    : super(searchFieldLabel: 'Abrir arquivo rápido');
  final List<WorkspaceEntry> files;
  @override
  List<Widget>? buildActions(BuildContext context) => <Widget>[
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );
  @override
  Widget buildResults(BuildContext context) => _list(context);
  @override
  Widget buildSuggestions(BuildContext context) => _list(context);
  Widget _list(BuildContext context) {
    final String needle = query.toLowerCase();
    final List<WorkspaceEntry> visible = files
        .where(
          (WorkspaceEntry item) => item.name.toLowerCase().contains(needle),
        )
        .take(100)
        .toList();
    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (_, int index) {
        final WorkspaceEntry entry = visible[index];
        return ListTile(
          leading: Icon(entryIcon(entry), color: entryColor(context, entry)),
          title: Text(entry.name),
          subtitle: Text(entry.relativePath),
          onTap: () => close(context, entry),
        );
      },
    );
  }
}
