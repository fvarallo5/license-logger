import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LicenseLoggerApp());
}

class LicenseLoggerApp extends StatelessWidget {
  const LicenseLoggerApp({super.key, this.state});

  /// Tests pass a preloaded [AppState]. The live app creates one on launch.
  final AppState? state;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'LicenseLogger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const AppShell(),
    );
    if (state != null) {
      return ChangeNotifierProvider<AppState>.value(value: state!, child: app);
    }
    return ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: app,
    );
  }
}
