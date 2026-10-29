import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/lesson.dart';
import '../theme/app_theme.dart';

/// Compact month grid. Dots mark practice (yellow) and instruction (green).
class MonthDots extends StatelessWidget {
  const MonthDots({
    super.key,
    required this.month,
    required this.lessons,
    this.selected,
    this.onSelect,
    this.onPrevMonth,
    this.onNextMonth,
    this.onAdd,
    this.embedded = false,
  });

  final DateTime month;
  final List<Lesson> lessons;
  final DateTime? selected;
  final ValueChanged<DateTime>? onSelect;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback? onAdd;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final lead = first.weekday % 7;
    final cells = lead + daysInMonth;
    final rows = (cells + 6) ~/ 7;
    final today = DateTime.now();
    final monthHours = lessons
        .where((l) =>
            l.status == LessonStatus.done &&
            l.start.year == month.year &&
            l.start.month == month.month)
        .fold(0.0, (s, l) => s + l.hours);

    final practiceDays = <int>{};
    final instructionDays = <int>{};
    for (final l in lessons) {
      if (l.start.year != month.year || l.start.month != month.month) continue;
      if (l.status != LessonStatus.done && !l.isOpen) continue;
      if (l.kind == DriveKind.instruction) {
        instructionDays.add(l.start.day);
      } else {
        practiceDays.add(l.start.day);
      }
    }

    final body = Column(
      children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onPrevMonth,
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat.yMMMM().format(first),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      '${monthHours.toStringAsFixed(1)} h this month',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onAdd != null)
                IconButton(
                  tooltip: 'Log a past drive',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
          Row(
            children: [
              for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _cell(
                      context,
                      index: r * 7 + c,
                      lead: lead,
                      daysInMonth: daysInMonth,
                      first: first,
                      today: today,
                      practiceDays: practiceDays,
                      instructionDays: instructionDays,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppColors.accent),
              const SizedBox(width: 4),
              Text('Practice', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 12),
              _legendDot(AppColors.success),
              const SizedBox(width: 4),
              Text('Instruction', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
    );
    if (embedded) return body;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: body,
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _cell(
    BuildContext context, {
    required int index,
    required int lead,
    required int daysInMonth,
    required DateTime first,
    required DateTime today,
    required Set<int> practiceDays,
    required Set<int> instructionDays,
  }) {
    final dayNum = index - lead + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 38);
    }
    final date = DateTime(first.year, first.month, dayNum);
    final isSel = selected != null &&
        selected!.year == date.year &&
        selected!.month == date.month &&
        selected!.day == date.day;
    final isToday = today.year == date.year &&
        today.month == date.month &&
        today.day == date.day;
    final practice = practiceDays.contains(dayNum);
    final instruction = instructionDays.contains(dayNum);

    return InkWell(
      onTap: onSelect == null ? null : () => onSelect!(date),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 38,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isToday && !isSel
                ? Border.all(color: AppColors.accent, width: 1.4)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel || isToday ? FontWeight.w800 : FontWeight.w600,
                  color: isSel ? Colors.white : AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (practice)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                    ),
                  if (instruction)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSel ? Colors.white : AppColors.success,
                      ),
                    ),
                  if (!practice && !instruction)
                    const SizedBox(width: 5, height: 5),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
