import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/lesson.dart';
import '../services/hour_credit.dart';
import '../state/app_state.dart';
import '../widgets/hours_arc.dart';

class HoursScreen extends StatelessWidget {
  const HoursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final student = state.settings.seat == LessonSeat.student;
    final rows = state.periodLessons;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text('Hours', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            student
                ? 'Permit progress. A trip needs 15 miles per hour of driving to save.'
                : 'Hours you have taught.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          HoursArc(
            hours: state.totalHours,
            nightHours: state.totalNightHours,
            goal: state.settings.hourGoal,
            nightGoal: state.settings.nightGoal,
            caption: student ? 'Permit hours' : 'Taught hours',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Night',
                  value: '${state.totalNightHours.toStringAsFixed(1)} / ${state.settings.nightGoal.toStringAsFixed(0)} h',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: 'Left',
                  value: formatHours((state.settings.hourGoal - state.totalHours).clamp(0, state.settings.hourGoal)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => _copyReport(context, state),
            icon: const Icon(Icons.ios_share),
            label: const Text('Copy hours report'),
          ),
          const SizedBox(height: 16),
          SegmentedButton<HoursPeriod>(
            segments: const [
              ButtonSegment(value: HoursPeriod.week, label: Text('Week')),
              ButtonSegment(value: HoursPeriod.month, label: Text('Month')),
              ButtonSegment(value: HoursPeriod.all, label: Text('All')),
            ],
            selected: {state.period},
            onSelectionChanged: (set) => state.setPeriod(set.first),
          ),
          const SizedBox(height: 8),
          Text(
            'Week and month filter this list. The arc is lifetime hours.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('No finished drives in this period.'),
            )
          else
            for (final lesson in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(formatLessonWhen(lesson.start, lesson.end)),
                subtitle: Text(
                  '${formatHours(lesson.hours)} counted · ${formatMiles(lesson.miles)}'
                  '${lesson.nightHours > 0 ? ' · ${formatHours(lesson.nightHours)} night' : ''}'
                  '${lesson.creditedSeconds < lesson.durationSeconds ? ' · clock ${formatHours(lesson.elapsedHours)}' : ''}',
                ),
              ),
        ],
      ),
    );
  }
}

Future<void> _copyReport(BuildContext context, AppState state) async {
  final s = state.settings;
  final date = DateFormat.yMMMd().format(DateTime.now());
  final buf = StringBuffer()
    ..writeln('LicenseLogger hours')
    ..writeln('${s.displayName}${s.stateName.isEmpty ? '' : ' · ${s.stateName}'}')
    ..writeln('As of $date')
    ..writeln(
      'Permit hours: ${state.totalHours.toStringAsFixed(1)} / ${s.hourGoal.toStringAsFixed(0)}',
    )
    ..writeln(
      'Night hours: ${state.totalNightHours.toStringAsFixed(1)} / ${s.nightGoal.toStringAsFixed(0)}',
    )
    ..writeln('Rule: ${HourCredit.minAverageMph.toStringAsFixed(0)} miles per hour of driving to save a trip.')
    ..writeln('')
    ..writeln('Drives');
  final done = state.lessons.where((l) => l.status == LessonStatus.done);
  if (done.isEmpty) {
    buf.writeln('None yet.');
  } else {
    for (final lesson in done) {
      buf.writeln(
        '- ${formatLessonWhen(lesson.start, lesson.end)} · ${formatHours(lesson.hours)} · ${formatMiles(lesson.miles)} · ${lesson.kind == DriveKind.instruction ? 'Instruction' : 'Practice'}',
      );
    }
  }
  buf.writeln('');
  buf.writeln('Not a DMV filing. Confirm hours with your state.');
  await Clipboard.setData(ClipboardData(text: buf.toString()));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hours report copied')),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
