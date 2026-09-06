import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../workspace/domain/workspace_entry.dart';
import '../workspace/presentation/workspace_controller.dart';

class WorkspaceSearchPanel extends StatefulWidget {
  const WorkspaceSearchPanel({required this.onOpenResult, super.key});

  final void Function(SearchMatch match) onOpenResult;

  @override
  State<WorkspaceSearchPanel> createState() => _WorkspaceSearchPanelState();
}

class _WorkspaceSearchPanelState extends State<WorkspaceSearchPanel> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  List<SearchMatch> _results = <SearchMatch>[];
  bool _loading = false;
  bool _caseSensitive = false;
  int _searchGeneration = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasWorkspace = context.watch<WorkspaceController>().hasWorkspace;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: _query,
            enabled: hasWorkspace,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hasWorkspace
                  ? 'Pesquisar no projeto'
                  : 'Abra uma pasta primeiro',
              prefixIcon: const Icon(Icons.search, size: 19),
              suffixIcon: IconButton(
                tooltip: 'Diferenciar maiúsculas',
                onPressed: hasWorkspace
                    ? () {
                        setState(() => _caseSensitive = !_caseSensitive);
                        _search();
                      }
                    : null,
                icon: Icon(
                  Icons.text_fields,
                  size: 18,
                  color: _caseSensitive
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _search);
            },
            onSubmitted: (_) => _search(),
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    _query.text.isEmpty
                        ? 'Digite para pesquisar em todos os arquivos.'
                        : 'Nenhum resultado.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SearchMatch match = _results[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.manage_search, size: 19),
                      title: Text(
                        match.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      subtitle: Text(
                        '${match.line}:${match.column}  ${match.preview.trim()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                        ),
                      ),
                      onTap: () => widget.onOpenResult(match),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _search() async {
    final int generation = ++_searchGeneration;
    final String query = _query.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = <SearchMatch>[];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final List<SearchMatch> results = await context
        .read<WorkspaceController>()
        .search(query, caseSensitive: _caseSensitive);
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }
}
