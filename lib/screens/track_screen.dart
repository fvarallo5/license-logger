import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/lesson.dart';
import '../services/hour_credit.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/drives_map.dart';
import 'log_lesson_sheet.dart';

class TrackScreen extends StatelessWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final live = state.live;
    final scheme = Theme.of(context).colorScheme;
    final mapped = state.lessons.where((l) => l.hasMapGeometry).take(8).toList();
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(state.error!, style: TextStyle(color: scheme.error)),
            ),
          DrivesMap(
            lessons: mapped,
            liveRoute: live != null ? state.liveRoute : const [],
            live: live != null,
            emptyMessage: 'Your practice routes draw here after a GPS drive.',
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: live != null
                ? AppColors.yellow.withValues(alpha: 0.18)
                : scheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: live != null ? AppColors.yellow : scheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                children: [
                  Text(
                    live == null
                        ? 'Ready to log hours'
                        : live.kind == DriveKind.instruction
                            ? 'Logging instruction'
                            : 'Logging a practice drive',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    live == null ? '0:00' : formatDuration(state.liveElapsed),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    live == null
                        ? formatMiles(0)
                        : '${formatMiles(state.liveMiles)} · ${formatHours(state.liveCreditedHours)} counts',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    live == null
                        ? 'Permit hours count at ${HourCredit.minAverageMph.toStringAsFixed(0)} mph.'
                        : _creditHint(state),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<DriveKind>(
                    segments: const [
                      ButtonSegment(value: DriveKind.practice, label: Text('Practice')),
                      ButtonSegment(value: DriveKind.instruction, label: Text('Instruction')),
                    ],
                    selected: {live?.kind ?? state.nextKind},
                    onSelectionChanged: live != null
                        ? (set) {}
                        : (set) => state.setNextKind(set.first),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: live == null ? AppColors.green : scheme.error,
                      ),
                      onPressed: live == null ? () => state.startLesson() : () => state.endLesson(),
                      child: Text(live == null ? 'Start drive' : 'End drive'),
                    ),
                  ),
                  if (state.settings.autoDetect) ...[
                    const SizedBox(height: 10),
                    Text(
                      state.autoTrackCaption,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (state.activity.gateEnabled &&
                        state.activity.available &&
                        !state.activity.hasPermission &&
                        live == null)
                      TextButton(
                        onPressed: () => state.requestMotionPermission(),
                        child: const Text('Allow Motion & Fitness'),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showLogLessonSheet(context),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Log a past drive'),
          ),
        ],
      ),
    );
  }
}

String _creditHint(AppState state) {
  final need = HourCredit.minMilesFor(state.liveElapsed);
  if (state.liveMiles + 0.05 >= need && need > 0) {
    return 'Miles cover this clock at ${HourCredit.minAverageMph.toStringAsFixed(0)} mph.';
  }
  return 'Need ${formatMiles(need)} for this clock · ${HourCredit.minAverageMph.toStringAsFixed(0)} mph rule.';
}
