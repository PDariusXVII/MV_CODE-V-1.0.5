import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/workspace_entry.dart';
import 'workspace_controller.dart';

enum _EntryAction {
  newFile,
  newFolder,
  rename,
  copy,
  cut,
  paste,
  import,
  delete,
}

class FileBrowser extends StatelessWidget {
  const FileBrowser({super.key});

  @override
  Widget build(BuildContext context) {
    final WorkspaceController controller = context.watch<WorkspaceController>();
    final WorkspaceEntry? root = controller.root;
    if (root == null) {
      return _EmptyExplorer(onOpen: controller.pickWorkspace);
    }

    return Column(
      children: <Widget>[
        Container(
          height: 42,
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Tooltip(
                  message: root.name,
                  child: Text(
                    root.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Novo arquivo',
                icon: const Icon(Icons.note_add_outlined, size: 19),
                onPressed: () => _create(context, folder: false),
              ),
              IconButton(
                tooltip: 'Nova pasta',
                icon: const Icon(Icons.create_new_folder_outlined, size: 19),
                onPressed: () => _create(context, folder: true),
              ),
              IconButton(
                tooltip: 'Atualizar',
                icon: const Icon(Icons.refresh, size: 19),
                onPressed: controller.refresh,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 32),
            children: <Widget>[
              for (final WorkspaceEntry entry in controller.childrenOf(
                root.uri,
              ))
                _EntryTile(entry: entry, depth: 0),
            ],
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextButton.icon(
                  onPressed: controller.pickWorkspace,
                  icon: const Icon(Icons.folder_open, size: 17),
                  label: const Text('Trocar pasta'),
                ),
              ),
              IconButton(
                tooltip: 'Importar arquivos',
                onPressed: controller.importFiles,
                icon: const Icon(Icons.file_download_outlined, size: 19),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, {required bool folder}) async {
    final String? name = await _nameDialog(
      context,
      title: folder ? 'Nova pasta' : 'Novo arquivo',
      hint: folder ? 'pasta' : 'arquivo.dart',
    );
    if (name == null || !context.mounted) return;
    final WorkspaceController controller = context.read<WorkspaceController>();
    if (folder) {
      await controller.createDirectory(name);
    } else {
      await controller.createFile(name);
    }
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.depth});

  final WorkspaceEntry entry;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final WorkspaceController controller = context.watch<WorkspaceController>();
    final bool expanded = controller.isExpanded(entry.uri);
    final bool selected = controller.selected?.uri == entry.uri;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.14)
              : Colors.transparent,
          child: InkWell(
            onTap: () => controller.openFile(entry),
            onLongPress: () => _showActions(context),
            child: SizedBox(
              height: 33,
              child: Row(
                children: <Widget>[
                  SizedBox(width: 7 + depth * 14),
                  if (entry.isDirectory)
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.chevron_right,
                      size: 18,
                    )
                  else
                    const SizedBox(width: 18),
                  Icon(
                    entryIcon(entry),
                    size: 18,
                    color: entryColor(context, entry),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  PopupMenuButton<_EntryAction>(
                    tooltip: 'Ações',
                    padding: EdgeInsets.zero,
                    iconSize: 17,
                    onSelected: (_EntryAction action) =>
                        _perform(context, action),
                    itemBuilder: (_) => <PopupMenuEntry<_EntryAction>>[
                      if (entry.isDirectory) ...<PopupMenuEntry<_EntryAction>>[
                        const PopupMenuItem(
                          value: _EntryAction.newFile,
                          child: _MenuLabel(
                            Icons.note_add_outlined,
                            'Novo arquivo',
                          ),
                        ),
                        const PopupMenuItem(
                          value: _EntryAction.newFolder,
                          child: _MenuLabel(
                            Icons.create_new_folder_outlined,
                            'Nova pasta',
                          ),
                        ),
                        const PopupMenuItem(
                          value: _EntryAction.import,
                          child: _MenuLabel(
                            Icons.file_download_outlined,
                            'Importar',
                          ),
                        ),
                        if (controller.clipboard != null)
                          const PopupMenuItem(
                            value: _EntryAction.paste,
                            child: _MenuLabel(Icons.content_paste, 'Colar'),
                          ),
                        const PopupMenuDivider(),
                      ],
                      const PopupMenuItem(
                        value: _EntryAction.rename,
                        child: _MenuLabel(
                          Icons.drive_file_rename_outline,
                          'Renomear',
                        ),
                      ),
                      const PopupMenuItem(
                        value: _EntryAction.copy,
                        child: _MenuLabel(Icons.copy_outlined, 'Copiar'),
                      ),
                      const PopupMenuItem(
                        value: _EntryAction.cut,
                        child: _MenuLabel(Icons.content_cut, 'Mover'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _EntryAction.delete,
                        child: _MenuLabel(Icons.delete_outline, 'Excluir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (entry.isDirectory && expanded)
          if (!controller.isLoaded(entry.uri))
            const Padding(
              padding: EdgeInsets.all(6),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else
            for (final WorkspaceEntry child in controller.childrenOf(entry.uri))
              _EntryTile(entry: child, depth: depth + 1),
      ],
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Renomear'),
              onTap: () {
                Navigator.pop(sheetContext);
                _perform(context, _EntryAction.rename);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copiar'),
              onTap: () {
                Navigator.pop(sheetContext);
                _perform(context, _EntryAction.copy);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_cut),
              title: const Text('Mover'),
              onTap: () {
                Navigator.pop(sheetContext);
                _perform(context, _EntryAction.cut);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Excluir'),
              onTap: () {
                Navigator.pop(sheetContext);
                _perform(context, _EntryAction.delete);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _perform(BuildContext context, _EntryAction action) async {
    final WorkspaceController controller = context.read<WorkspaceController>();
    controller.select(entry);
    switch (action) {
      case _EntryAction.newFile:
      case _EntryAction.newFolder:
        final bool folder = action == _EntryAction.newFolder;
        final String? name = await _nameDialog(
          context,
          title: folder
              ? 'Nova pasta em ${entry.name}'
              : 'Novo arquivo em ${entry.name}',
          hint: folder ? 'pasta' : 'arquivo.dart',
        );
        if (name == null) return;
        if (folder) {
          await controller.createDirectory(name, parentUri: entry.uri);
        } else {
          await controller.createFile(name, parentUri: entry.uri);
        }
        break;
      case _EntryAction.rename:
        final String? name = await _nameDialog(
          context,
          title: 'Renomear',
          hint: entry.name,
          initialValue: entry.name,
        );
        if (name != null && name != entry.name) {
          await controller.renameEntry(entry, name);
        }
        break;
      case _EntryAction.copy:
        controller.copy(entry);
        break;
      case _EntryAction.cut:
        controller.copy(entry, cut: true);
        break;
      case _EntryAction.paste:
        await controller.paste(targetParentUri: entry.uri);
        break;
      case _EntryAction.import:
        await controller.importFiles(targetParentUri: entry.uri);
        break;
      case _EntryAction.delete:
        final bool confirmed = await _confirmDelete(context, entry.name);
        if (confirmed) await controller.deleteEntry(entry);
        break;
    }
  }
}

class _EmptyExplorer extends StatelessWidget {
  const _EmptyExplorer({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.folder_open_outlined,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'Nenhuma pasta aberta',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Escolha uma pasta. O MV Code só acessará o local autorizado por você.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.folder_open),
            label: const Text('Abrir pasta'),
          ),
        ],
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 19),
      const SizedBox(width: 10),
      Text(label),
    ],
  );
}

IconData entryIcon(WorkspaceEntry entry) {
  if (entry.isDirectory) return Icons.folder_outlined;
  return switch (entry.extension) {
    'html' || 'htm' => Icons.html,
    'css' || 'scss' || 'less' => Icons.palette_outlined,
    'js' || 'jsx' || 'ts' || 'tsx' => Icons.javascript,
    'json' || 'yaml' || 'yml' || 'xml' => Icons.data_object,
    'md' => Icons.description_outlined,
    'png' ||
    'jpg' ||
    'jpeg' ||
    'gif' ||
    'webp' ||
    'svg' => Icons.image_outlined,
    _ => Icons.insert_drive_file_outlined,
  };
}

Color entryColor(BuildContext context, WorkspaceEntry entry) {
  if (entry.isDirectory) return const Color(0xFFE0B04B);
  return switch (entry.extension) {
    'html' || 'htm' => const Color(0xFFE66B3D),
    'css' || 'scss' || 'less' => const Color(0xFF4A88E8),
    'js' || 'jsx' => const Color(0xFFE8CC45),
    'ts' || 'tsx' => const Color(0xFF4A9BE8),
    'dart' => const Color(0xFF42B8E8),
    'kt' || 'kts' => const Color(0xFFB575E8),
    'json' => const Color(0xFFC6BD55),
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

Future<String?> _nameDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String? initialValue,
}) async {
  final TextEditingController input = TextEditingController(text: initialValue);
  final String? value = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: input,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (String value) {
          if (value.trim().isNotEmpty)
            Navigator.pop(dialogContext, value.trim());
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
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  input.dispose();
  return value;
}

Future<bool> _confirmDelete(BuildContext context, String name) async {
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          icon: const Icon(Icons.warning_amber),
          title: const Text('Excluir permanentemente?'),
          content: Text(
            '“$name” será removido do dispositivo. Esta ação não pode ser desfeita.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir'),
            ),
          ],
        ),
      ) ??
      false;
}
