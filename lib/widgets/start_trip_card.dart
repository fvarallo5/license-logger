import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/lesson.dart';
import '../services/hour_credit.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../screens/log_lesson_sheet.dart';

/// Compact start/end control for the Dashboard.
class StartTripCard extends StatelessWidget {
  const StartTripCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final live = state.live;
    final scheme = Theme.of(context).colorScheme;
    final driving = live != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: driving ? AppColors.yellow : AppColors.green,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (driving ? AppColors.yellow : AppColors.green)
                .withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'TRACK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: (driving ? AppColors.ink : Colors.white)
                      .withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              _KindChip(
                selected: (live?.kind ?? state.nextKind) == DriveKind.practice,
                label: 'Practice',
                dark: driving,
                onTap: live != null
                    ? null
                    : () => state.setNextKind(DriveKind.practice),
              ),
              const SizedBox(width: 6),
              _KindChip(
                selected: (live?.kind ?? state.nextKind) == DriveKind.instruction,
                label: 'Lesson',
                dark: driving,
                onTap: live != null
                    ? null
                    : () => state.setNextKind(DriveKind.instruction),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      live == null ? '0:00' : formatDuration(state.liveElapsed),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -1,
                        color: driving ? AppColors.ink : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      live == null
                          ? '15 miles per hour of driving to save'
                          : _liveHint(state),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (driving ? AppColors.ink : Colors.white)
                            .withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: driving ? AppColors.ink : Colors.white,
                    foregroundColor: driving ? AppColors.yellow : AppColors.greenDeep,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: live == null
                      ? () => state.startLesson()
                      : () => state.endLesson(),
                  child: Text(live == null ? 'Start drive' : 'End drive'),
                ),
              ),
            ],
          ),
          if (state.settings.autoDetect) ...[
            const SizedBox(height: 8),
            Text(
              state.autoTrackCaption,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: (driving ? AppColors.ink : Colors.white)
                    .withValues(alpha: 0.75),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => showLogLessonSheet(context),
              style: TextButton.styleFrom(
                foregroundColor: driving ? AppColors.ink : Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Log a past drive'),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: driving ? AppColors.ink : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.error!,
                style: TextStyle(
                  color: state.error == HourCredit.tooShortMessage
                      ? AppColors.yellow
                      : (driving ? scheme.error : AppColors.yellowSoft),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _liveHint(AppState state) {
  final need = HourCredit.minMilesFor(state.liveElapsed);
  final left = HourCredit.milesNeeded(
    durationSeconds: state.liveElapsed.inSeconds,
    miles: state.liveMiles,
  );
  if (left > 0.05) {
    return '${formatMiles(state.liveMiles)} · need ${formatMiles(need)} to save';
  }
  return '${formatMiles(state.liveMiles)} · ${formatHours(state.liveCreditedHours)} counts';
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.selected,
    required this.label,
    required this.dark,
    this.onTap,
  });

  final bool selected;
  final String label;
  final bool dark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = dark ? AppColors.ink : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? on.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on.withValues(alpha: selected ? 0.9 : 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: on,
          ),
        ),
      ),
    );
  }
}
