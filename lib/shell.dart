import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'screens/hours_screen.dart';
import 'screens/lessons_screen.dart';
import 'screens/profile_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_header.dart';

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

    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom.clamp(0.0, 24.0);
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(),
          const AppAccentBar(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: IndexedStack(
                index: _index,
                children: const [
                  DashboardScreen(),
                  LessonsScreen(),
                  HoursScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(bottom: bottomInset),
          viewPadding: mq.viewPadding.copyWith(bottom: bottomInset),
        ),
        child: NavigationBar(
          height: 44,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Lessons',
            ),
            NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              selectedIcon: Icon(Icons.schedule),
              label: 'Hours',
            ),
          ],
        ),
      ),
    );
  }
}

class AppAccentBar extends StatelessWidget {
  const AppAccentBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.green, AppColors.yellow, AppColors.lime],
        ),
      ),
    );
  }
}
