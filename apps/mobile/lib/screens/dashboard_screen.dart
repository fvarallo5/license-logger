import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/hours_calc.dart';
import '../format.dart';
import '../screens/log_lesson_sheet.dart';
import '../screens/settings_sheet.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/hours_arc.dart';
import '../widgets/ll_widgets.dart';
import '../widgets/requirements_card.dart';
import '../widgets/start_trip_card.dart';
import '../widgets/week_calendar.dart';

/// Student home: hours ring, week calendar, recent drives, sticky Start drive.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onOpenProfile, this.onOpenLogs});

  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenLogs;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final name = state.settings.firstName.trim();
    final now = DateTime.now();
    final hi = name.isEmpty ? greetingFor(now) : '${greetingFor(now)}, $name';
    final j = state.jurisdiction;
    final rule = state.ruleSet;
    final sum = state.hoursSummary;
    final recent = state.lessons.take(3).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(LL.s4, 0, LL.s4, 200),
          children: [
            LLTopBar(
              center: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LicenseLogger', style: llText(LL.fsSm, weight: FontWeight.w700)),
                  Text(
                    state.headerStatus,
                    style: llText(LL.fsXs, color: state.live != null ? LL.warning : LL.textMuted),
                  ),
                ],
              ),
              trailing: Row(
                children: [
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => showSettingsSheet(context),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onOpenProfile,
                    child: Avatar(state.initials, size: 40),
                  ),
                ],
              ),
            ),
            Text('${fmtWeekday(now)}, ${fmtMonth(now)} ${now.day}'.toUpperCase(), style: llLabel()),
            const SizedBox(height: LL.s1),
            Text(hi, style: llText(LL.fs2xl, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Log the hours. Hit the checklist. Take the test.',
              style: llText(LL.fsSm, color: LL.textMuted, weight: FontWeight.w500),
            ),
            const SizedBox(height: LL.s4),
            WeekCalendar(
              lessons: state.lessons,
              onAdd: () => showLogLessonSheet(context),
            ),
            const SizedBox(height: LL.s3),
            if (j != null && rule != null)
              RequirementsCard(
                j: j,
                rule: rule,
                sum: sum ?? computeHours(const [], rule),
                permitIssued: state.settings.permitIssued,
              )
            else
              HoursArc(
                hours: state.totalHours,
                nightHours: state.totalNightHours,
                goal: state.settings.hourGoal,
                nightGoal: state.settings.nightGoal,
                caption: 'Permit hours',
              ),
            const SizedBox(height: LL.s3),
            LLCard(
              padding: const EdgeInsets.fromLTRB(LL.s4, LL.s3, LL.s4, LL.s1),
              child: Column(
                children: [
                  SectionHeader(
                    'Recent drives',
                    trailing: LinkText('All drives', onTap: onOpenLogs),
                  ),
                  const SizedBox(height: LL.s2),
                  if (recent.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: LL.s3),
                      child: Text(
                        'No practice drives yet. Start a trip below.',
                        style: llText(LL.fsSm, color: LL.textMuted),
                      ),
                    )
                  else
                    for (final (i, d) in recent.indexed)
                      DriveRow(lesson: d, showDivider: i > 0),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 28,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [LL.bg.withValues(alpha: 0), LL.bg],
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: LL.s4,
          right: LL.s4,
          bottom: LL.s3,
          child: StartTripCard(),
        ),
      ],
    );
  }
}
