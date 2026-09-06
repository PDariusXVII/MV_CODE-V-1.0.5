import 'package:flutter/material.dart';

class SymbolBar extends StatelessWidget {
  const SymbolBar({required this.onInsert, required this.onCommand, super.key});

  final ValueChanged<String> onInsert;
  final ValueChanged<String> onCommand;

  static const List<(String, String, bool)> _symbols = <(String, String, bool)>[
    ('Esc', 'escape', true),
    ('Tab', '\t', false),
    ('←', 'cursorLeft', true),
    ('↑', 'cursorUp', true),
    ('↓', 'cursorDown', true),
    ('→', 'cursorRight', true),
    ('{', '{', false),
    ('}', '}', false),
    ('(', '(', false),
    (')', ')', false),
    ('[', '[', false),
    (']', ']', false),
    ('<', '<', false),
    ('>', '>', false),
    ('=', '=', false),
    (';', ';', false),
    (':', ':', false),
    ('"', '"', false),
    ("'", "'", false),
    ('/', '/', false),
    ('\\', '\\', false),
    ('_', '_', false),
    ('-', '-', false),
    ('+', '+', false),
    ('*', '*', false),
    ('#', '#', false),
    ('@', '@', false),
    ('&', '&', false),
    ('|', '|', false),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        itemCount: _symbols.length,
        separatorBuilder: (_, __) => const SizedBox(width: 3),
        itemBuilder: (BuildContext context, int index) {
          final (String label, String value, bool command) = _symbols[index];
          return Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(5),
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: () => command ? onCommand(value) : onInsert(value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 34),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
