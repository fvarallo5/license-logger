import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'screens/lessons_screen.dart';
import 'screens/license/license_hub_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/student/me_screen.dart';
import 'state/app_state.dart';
import 'widgets/bottom_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final backgrounded = state != AppLifecycleState.resumed;
    context.read<AppState>().setAppBackgrounded(backgrounded);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.settings.profileReady) {
      return const ProfileScreen();
    }

    Widget tab(Widget root) => SafeArea(bottom: false, child: root);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          tab(
            DashboardScreen(
              onOpenProfile: () => setState(() => _index = 3),
              onOpenLogs: () => setState(() => _index = 1),
            ),
          ),
          tab(const LessonsScreen()),
          tab(const LicenseHubScreen()),
          tab(const MeScreen()),
        ],
      ),
      bottomNavigationBar: LLBottomBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          (Icons.home_outlined, Icons.home_rounded, 'Home'),
          (Icons.route_outlined, Icons.route_rounded, 'Drives'),
          (Icons.workspace_premium_outlined, Icons.workspace_premium_rounded, 'License'),
          (Icons.person_outline_rounded, Icons.person_rounded, 'Me'),
        ],
      ),
    );
  }
}
