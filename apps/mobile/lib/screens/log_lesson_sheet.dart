import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/lesson.dart';
import '../services/hour_credit.dart';
import '../state/app_state.dart';

Future<void> showLogLessonSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const LogLessonSheet(),
  );
}

class LogLessonSheet extends StatefulWidget {
  const LogLessonSheet({super.key});

  @override
  State<LogLessonSheet> createState() => _LogLessonSheetState();
}

class _LogLessonSheetState extends State<LogLessonSheet> {
  late DateTime _day;
  TimeOfDay _start = const TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  final _miles = TextEditingController();
  final _meet = TextEditingController();
  final _notes = TextEditingController();
  DriveKind _kind = DriveKind.practice;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _miles.dispose();
    _meet.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _combine(TimeOfDay t) =>
      DateTime(_day.year, _day.month, _day.day, t.hour, t.minute);

  String _milesHelper() {
    var start = _combine(_start);
    var end = _combine(_end);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    final elapsed = end.difference(start);
    final need = HourCredit.minMilesFor(elapsed);
    final miles = double.tryParse(_miles.text.trim()) ?? 0;
    final counted = HourCredit.hours(
      durationSeconds: elapsed.inSeconds,
      miles: miles,
    );
    if (!HourCredit.canLog(durationSeconds: elapsed.inSeconds, miles: miles)) {
      return '${HourCredit.tooShortMessage} · need ${formatMiles(need)} for this clock (15 mi per hour).';
    }
    return '${formatMiles(need)} covers this clock. Counts as ${formatHours(counted)}.';
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, pad + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log a past drive', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<DriveKind>(
              segments: const [
                ButtonSegment(value: DriveKind.practice, label: Text('Practice')),
                ButtonSegment(value: DriveKind.instruction, label: Text('Instruction')),
              ],
              selected: {_kind},
              onSelectionChanged: (set) => setState(() => _kind = set.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              trailing: Text('${_day.month}/${_day.day}/${_day.year}'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _day = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              trailing: Text(_start.format(context)),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _start);
                if (picked != null) setState(() => _start = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End'),
              trailing: Text(_end.format(context)),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _end);
                if (picked != null) setState(() => _end = picked);
              },
            ),
            TextField(
              controller: _miles,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Miles',
                helperText: _milesHelper(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _meet,
              decoration: const InputDecoration(labelText: 'Meet / lot'),
            ),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                var start = _combine(_start);
                var end = _combine(_end);
                if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
                final miles = double.tryParse(_miles.text.trim()) ?? 0;
                if (!HourCredit.canLog(
                  durationSeconds: end.difference(start).inSeconds,
                  miles: miles,
                )) {
                  setState(() {});
                  return;
                }
                final ok = await context.read<AppState>().logManual(
                      start: start,
                      end: end,
                      miles: miles,
                      meet: _meet.text.trim(),
                      notes: _notes.text.trim(),
                      kind: _kind,
                    );
                if (ok && context.mounted) Navigator.pop(context);
              },
              child: const Text('Save drive'),
            ),
          ],
        ),
      ),
    );
  }
}
