import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/log_lesson_sheet.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/start_trip_card.dart';
import '../widgets/test_ready_card.dart';
import '../widgets/week_calendar.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final name = state.settings.firstName.trim();
    final hi = name.isEmpty ? 'Hey' : 'Hey $name';
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            hi,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Log the hours. Hit the checklist. Take the test.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.greenDeep,
                ),
          ),
          const SizedBox(height: 14),
          const StartTripCard(),
          const SizedBox(height: 14),
          WeekCalendar(
            lessons: state.lessons,
            onAdd: () => showLogLessonSheet(context),
          ),
          const SizedBox(height: 14),
          const TestReadyCard(),
        ],
      ),
    );
  }
}
