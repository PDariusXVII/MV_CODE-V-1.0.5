import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/settings/settings_controller.dart';
import 'features/workspace/data/native_saf_data_source.dart';
import 'features/workspace/data/workspace_repository.dart';
import 'features/workspace/presentation/workspace_controller.dart';
import 'features/workspace/presentation/workspace_screen.dart';

class MVCodeApp extends StatelessWidget {
  const MVCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController()..load(),
        ),
        ChangeNotifierProvider<WorkspaceController>(
          create: (_) => WorkspaceController(
            WorkspaceRepository(const NativeSafDataSource()),
          )..restoreWorkspace(),
        ),
      ],
      child: Consumer<SettingsController>(
        builder: (BuildContext context, SettingsController settings, _) {
          return MaterialApp(
            title: 'MV Code',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const WorkspaceScreen(),
          );
        },
      ),
    );
  }
}
