import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/lesson.dart';
import '../theme/app_theme.dart';
import 'month_dots.dart';

/// Week strip by default; expands to the month grid.
class WeekCalendar extends StatefulWidget {
  const WeekCalendar({
    super.key,
    required this.lessons,
    this.onAdd,
  });

  final List<Lesson> lessons;
  final VoidCallback? onAdd;

  @override
  State<WeekCalendar> createState() => _WeekCalendarState();
}

class _WeekCalendarState extends State<WeekCalendar> {
  late DateTime _month;
  DateTime? _selected;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  DateTime _weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday % 7));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final anchor = _selected ?? DateTime.now();
    final start = _weekStart(anchor);
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final weekHours = widget.lessons
        .where((l) =>
            l.status == LessonStatus.done &&
            !l.start.isBefore(start) &&
            l.start.isBefore(start.add(const Duration(days: 7))))
        .fold(0.0, (s, l) => s + l.hours);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _expanded
                          ? DateFormat.yMMMM().format(_month)
                          : 'This week',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _expanded
                          ? 'Tap a day · expand stays open'
                          : '${weekHours.toStringAsFixed(1)} h logged',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'This week' : 'Month'),
              ),
              if (widget.onAdd != null)
                IconButton(
                  tooltip: 'Log a past drive',
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
          if (_expanded)
            MonthDots(
              month: _month,
              lessons: widget.lessons,
              selected: _selected,
              embedded: true,
              onPrevMonth: () => setState(() {
                _month = DateTime(_month.year, _month.month - 1);
                _selected = null;
              }),
              onNextMonth: () => setState(() {
                _month = DateTime(_month.year, _month.month + 1);
                _selected = null;
              }),
              onSelect: (d) => setState(() {
                _selected = _selected != null &&
                        _selected!.year == d.year &&
                        _selected!.month == d.month &&
                        _selected!.day == d.day
                    ? null
                    : d;
                _month = DateTime(d.year, d.month);
              }),
            )
          else
            Row(
              children: [
                for (final day in days)
                  Expanded(child: _weekCell(context, day)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _weekCell(BuildContext context, DateTime date) {
    final today = DateTime.now();
    final isToday = today.year == date.year &&
        today.month == date.month &&
        today.day == date.day;
    final isSel = _selected != null &&
        _selected!.year == date.year &&
        _selected!.month == date.month &&
        _selected!.day == date.day;
    var practice = false;
    var instruction = false;
    for (final l in widget.lessons) {
      if (l.start.year != date.year ||
          l.start.month != date.month ||
          l.start.day != date.day) {
        continue;
      }
      if (l.status != LessonStatus.done && !l.isOpen) continue;
      if (l.kind == DriveKind.instruction) {
        instruction = true;
      } else {
        practice = true;
      }
    }
    final labels = const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return InkWell(
      onTap: () => setState(() {
        _selected = isSel ? null : date;
        _month = DateTime(date.year, date.month);
      }),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isToday && !isSel
              ? Border.all(color: AppColors.yellow, width: 1.6)
              : null,
        ),
        child: Column(
          children: [
            Text(
              labels[date.weekday % 7],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isSel ? Colors.white70 : AppColors.ink.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isSel ? Colors.white : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (practice)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.yellow,
                    ),
                  ),
                if (instruction)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSel ? Colors.white : AppColors.green,
                    ),
                  ),
                if (!practice && !instruction)
                  const SizedBox(width: 5, height: 5),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
