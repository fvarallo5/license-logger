import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/lesson.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/drives_map.dart';
import 'log_lesson_sheet.dart';

class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rows = state.lessons;
    final mapLessons = rows.where((l) => l.hasMapGeometry).take(12).toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            'Drives',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Routes draw as you drive. Yellow is practice. Green is instruction.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          DrivesMap(
            lessons: mapLessons,
            liveRoute: state.live != null ? state.liveRoute : const [],
            live: state.live != null,
            height: 280,
            emptyMessage: 'Your practice routes draw here after a GPS drive.',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showLogLessonSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Log a past drive'),
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No practice drives yet. Start a trip on Home.'),
            )
          else
            for (final lesson in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: lesson.kind == DriveKind.instruction
                      ? AppColors.success.withValues(alpha: 0.18)
                      : AppColors.accent.withValues(alpha: 0.35),
                  child: Icon(
                    lesson.kind == DriveKind.instruction
                        ? Icons.school_outlined
                        : Icons.directions_car_outlined,
                    size: 16,
                    color: lesson.kind == DriveKind.instruction
                        ? AppColors.success
                        : AppColors.text,
                  ),
                ),
                title: Text(
                  lesson.isOpen
                      ? 'Driving now'
                      : formatLessonWhen(lesson.start, lesson.end),
                ),
                subtitle: Text(
                  [
                    lesson.kind == DriveKind.instruction ? 'Instruction' : 'Practice',
                    formatHours(lesson.isOpen ? state.liveCreditedHours : lesson.hours),
                    formatMiles(lesson.isOpen ? state.liveMiles : lesson.miles),
                    if (lesson.meet.isNotEmpty) lesson.meet,
                    if (lesson.autoStarted) 'auto',
                  ].join(' · '),
                ),
                trailing: lesson.isOpen
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => state.deleteLesson(lesson.id),
                      ),
              ),
        ],
      ),
    );
  }
}
