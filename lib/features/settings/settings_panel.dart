import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'settings_controller.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: <Widget>[
        Text('APARÊNCIA', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 10),
        DropdownButtonFormField<ThemeMode>(
          value: settings.themeMode,
          decoration: const InputDecoration(labelText: 'Tema'),
          items: const <DropdownMenuItem<ThemeMode>>[
            DropdownMenuItem(value: ThemeMode.dark, child: Text('MV Dark')),
            DropdownMenuItem(value: ThemeMode.light, child: Text('MV Light')),
            DropdownMenuItem(value: ThemeMode.system, child: Text('Sistema')),
          ],
          onChanged: (ThemeMode? value) {
            if (value != null) settings.setThemeMode(value);
          },
        ),
        const SizedBox(height: 18),
        Text('Tamanho da fonte: ${settings.fontSize.round()}'),
        Slider(
          value: settings.fontSize,
          min: 11,
          max: 24,
          divisions: 13,
          onChanged: settings.setFontSize,
        ),
        DropdownButtonFormField<int>(
          value: settings.tabSize,
          decoration: const InputDecoration(labelText: 'Espaços por tabulação'),
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem(value: 2, child: Text('2 espaços')),
            DropdownMenuItem(value: 4, child: Text('4 espaços')),
            DropdownMenuItem(value: 8, child: Text('8 espaços')),
          ],
          onChanged: (int? value) {
            if (value != null) settings.setTabSize(value);
          },
        ),
        const Divider(height: 28),
        _SwitchTile(
          title: 'Quebra de linha',
          value: settings.wordWrap,
          onChanged: settings.setWordWrap,
        ),
        _SwitchTile(
          title: 'Números de linha',
          value: settings.lineNumbers,
          onChanged: settings.setLineNumbers,
        ),
        _SwitchTile(
          title: 'Salvar automaticamente',
          subtitle: 'Grava 1,2 s após a última edição.',
          value: settings.autoSave,
          onChanged: settings.setAutoSave,
        ),
        const Divider(height: 28),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline),
          title: Text('Privacidade local'),
          subtitle: Text(
            'Sem IA, telemetria, login ou tarefas em segundo plano.',
          ),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}
