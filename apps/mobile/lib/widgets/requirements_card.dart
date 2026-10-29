import 'package:flutter/material.dart';

import '../data/hours_calc.dart';
import '../data/state_rules.dart';
import '../format.dart';
import '../theme/app_theme.dart';
import 'll_widgets.dart';
import 'progress_ring.dart';
import 'rule_text.dart';

/// Progress toward the student's state requirement.
class RequirementsCard extends StatelessWidget {
  const RequirementsCard({
    super.key,
    required this.j,
    required this.rule,
    required this.sum,
    this.permitIssued,
    this.schoolGoalHours,
    this.schoolName,
    this.compact = false,
    this.showSupervisor = false,
  });

  final Jurisdiction j;
  final StateRuleSet rule;
  final HoursSummary sum;
  final DateTime? permitIssued;
  final double? schoolGoalHours;
  final String? schoolName;
  final bool compact;
  final bool showSupervisor;

  @override
  Widget build(BuildContext context) {

    final header = Row(
      children: [
        Expanded(
          child: Text('${j.stateName} requirements', style: llText(LL.fsMd, weight: FontWeight.w600)),
        ),
        if (rule.isUnconfirmed)
          const LLBadge('Unconfirmed', kind: BadgeKind.warn)
        else if (rule.noMinimum)
          const LLBadge('No hours minimum', kind: BadgeKind.neutral)
        else
          LLBadge(_shortCode(rule.formCode), kind: BadgeKind.neutral),
      ],
    );

    final List<Widget> body;
    if (sum.totalTarget == null) {
      body = [
        const SizedBox(height: LL.s3),
        Text(
          rule.noRuleOnFile
              ? 'No rule on file for ${j.stateName} for a permit issued ${permitIssued == null ? '—' : fmtDateLong(permitIssued!)}. '
                    'Keep logging; your hours and miles are saved.'
              : sum.alternative?.replacesHours ?? false
              ? 'You’re on this path: “${sum.alternative!.label}”. It has no hours target.'
              : rule.isUnconfirmed
              ? 'We couldn’t confirm ${j.stateName}’s practice-hour rule on an official state source, so we don’t show a target. '
                    'Keep logging; your hours and miles are saved.'
              : '${j.stateName} has no supervised-hours minimum in our research. Logging still helps you practice and track miles.',
          style: llText(LL.fsSm, color: LL.textMuted, height: 1.45),
        ),
        const SizedBox(height: LL.s3),
        _row('Total hours', rule.isUnconfirmed ? 'Unconfirmed' : 'None', null),
        _row(rule.nightLabel, rule.isUnconfirmed ? 'Unconfirmed' : 'None', null),
        const SizedBox(height: LL.s3),
        const Divider(),
        const SizedBox(height: LL.s3),
        _stats(sum, rule),
      ];
    } else {
      final total = sum.totalTarget!;
      final ring = ProgressRing(
        day: (sum.credited - sum.night) / 60,
        night: sum.night / 60,
        goal: total / 60,
        size: compact ? 120 : 168,
        stroke: compact ? 12 : 15,
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fmtCredit(sum.credited, rule, unit: false),
              style: llText(
                compact ? LL.fs2xl : (rule.logUnit == 'minutes' ? LL.fs2xl : LL.fs3xl),
                weight: FontWeight.w700,
                numeric: true,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'of ${fmtCredit(total, rule)}',
              style: llText(compact ? LL.fsXs : LL.fsSm, weight: FontWeight.w500, color: LL.textMuted),
            ),
          ],
        ),
      );
      String note(String field) => rule.isFieldUnconfirmed(field) ? 'unconfirmed' : 'not specified';
      final mult = rule.instructorMultiplier;
      final bars = <Widget>[
        _Bar(
          label: rule.nightLabel,
          value: sum.night,
          max: sum.nightTarget,
          note: note('night_minutes'),
          rule: rule,
          color: LL.night,
          icon: Icons.nightlight_round,
        ),
        if (sum.weatherTarget != null)
          _Bar(
            label: rule.weatherLabel,
            value: sum.weatherCredited,
            max: sum.weatherTarget,
            note: '',
            rule: rule,
            color: LL.weather,
            icon: Icons.water_drop_outlined,
          ),
        if (rule.lessonsCount)
          _Bar(
            label: 'Instructor${mult != 1 ? ' ×${mult == mult.roundToDouble() ? mult.toInt() : mult}' : ''}',
            value: sum.instructor,
            max: rule.instructorMaxMinutes == null ? null : (rule.instructorMaxMinutes! * mult).round(),
            note: 'no cap listed',
            rule: rule,
            color: LL.success,
            icon: Icons.school_outlined,
          ),
        if (schoolGoalHours != null)
          _Bar(
            label: '${(schoolName ?? 'School').split(' ').first} goal',
            value: sum.credited,
            max: (schoolGoalHours! * 60).round(),
            note: '',
            rule: rule,
            color: LL.accent,
          ),
      ];
      final barCol = Column(
        children: [
          for (final (i, b) in bars.indexed) ...[if (i > 0) const SizedBox(height: LL.s3), b],
        ],
      );
      body = [
        const SizedBox(height: LL.s4),
        if (compact)
          Row(
            children: [
              ring,
              const SizedBox(width: LL.s4),
              Expanded(child: barCol),
            ],
          )
        else ...[
          Center(child: ring),
          const SizedBox(height: LL.s4),
          barCol,
        ],
        if (rule.stages.isNotEmpty) ...[
          const SizedBox(height: LL.s4),
          Text('STAGES', style: llLabel()),
          const SizedBox(height: LL.s2),
          for (final st in sum.stages) _StageRow(st: st, rule: rule),
        ],
        if (_capChips(rule, sum).isNotEmpty) ...[
          const SizedBox(height: LL.s3),
          Wrap(spacing: 6, runSpacing: 6, children: _capChips(rule, sum)),
        ],
        const SizedBox(height: LL.s4),
        const Divider(),
        const SizedBox(height: LL.s3),
        _stats(sum, rule),
      ];
    }

    return LLCard(
      hero: !compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          ...body,
          if (showSupervisor) ...[const SizedBox(height: LL.s3), SupervisorReminder(rule: rule)],
          if (!compact) ...[
            const SizedBox(height: LL.s3),
            Text(
              rule.isUnconfirmed
                  ? 'Source: research checked ${fmtDateLong(rule.verifiedOn ?? rule.lastChecked ?? j.lastChecked ?? DateTime.now())}. Not on an official state page.'
                  : 'From ${rule.formCode.isEmpty ? 'the state rules page' : rule.formCode} · checked '
                        '${fmtDateLong(rule.verifiedOn ?? rule.lastChecked ?? j.lastChecked ?? DateTime.now())}'
                        '${rule.version > 1 ? ' · rule v${rule.version} for permits from ${fmtDateLong(rule.effectiveFrom)}' : ''}',
              style: llText(LL.fsXs, color: LL.textMuted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  static String _shortCode(String code) {
    final c = code.replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ').trim();
    if (c.isEmpty) return 'State rule';
    return c.length > 16 ? '${c.substring(0, 15)}…' : c;
  }

  Widget _row(String label, String value, Color? color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: llText(LL.fsSm, weight: FontWeight.w500)),
        ),
        LLBadge(value, kind: value == 'Unconfirmed' ? BadgeKind.warn : BadgeKind.neutral),
      ],
    ),
  );

  Widget _stats(HoursSummary sum, StateRuleSet rule) {
    final left = sum.remaining;
    return Row(
      children: [
        Expanded(
          child: StatBlock(label: 'GPS miles', value: sum.miles.toStringAsFixed(0), unit: 'mi'),
        ),
        Expanded(
          child: StatBlock(label: 'Drives', value: '${sum.practiceCount}'),
        ),
        Expanded(
          child: left == null
              ? StatBlock(
                  label: 'Logged',
                  value: fmtCredit(sum.raw, rule, unit: false),
                  unit: rule.logUnit == 'minutes' ? 'min' : 'h',
                )
              : StatBlock(
                  label: 'To go',
                  value: fmtCredit(left, rule, unit: false),
                  unit: rule.logUnit == 'minutes' ? 'min' : 'h',
                ),
        ),
      ],
    );
  }

  List<Widget> _capChips(StateRuleSet rule, HoursSummary sum) => [
    if (rule.dailyCapMinutes != null)
      LLChip('Max ${fmtCredit(rule.dailyCapMinutes!, rule)}/day counts', icon: Icons.today_outlined),
    if (rule.weeklyCapMinutes != null)
      LLChip('Max ${fmtCredit(rule.weeklyCapMinutes!, rule)}/week counts', icon: Icons.date_range_outlined),
    if (sum.pending > 0)
      LLChip('${fmtCredit(sum.pending, rule)} waiting for sign-off', icon: Icons.hourglass_top_rounded),
    if (sum.alternative != null) LLChip('Path: ${sum.alternative!.label}', icon: Icons.alt_route_rounded),
    if (sum.trimmedByCap > 0)
      LLChip('${fmtCredit(sum.trimmedByCap, rule)} over the cap', icon: Icons.content_cut_rounded),
    if (rule.logUnit == 'minutes') const LLChip('State log uses minutes', icon: Icons.timer_outlined),
  ];
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.max,
    required this.note,
    required this.rule,
    required this.color,
    this.icon,
  });
  final String label;
  final int value;
  final int? max;
  final String note; // shown when there is no target: "not specified" / "unconfirmed"
  final StateRuleSet rule;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final known = max != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: llText(LL.fsSm, weight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (known)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: fmtCredit(value, rule, unit: false),
                      style: llText(LL.fsSm, weight: FontWeight.w600, numeric: true),
                    ),
                    TextSpan(
                      text: ' / ${fmtCredit(max!, rule)}',
                      style: llText(LL.fsSm, color: LL.textMuted, numeric: true),
                    ),
                  ],
                ),
              )
            else
              Text('${fmtCredit(value, rule)} · $note', style: llText(LL.fsXs + 1, color: LL.textMuted, numeric: true)),
          ],
        ),
        const SizedBox(height: 6),
        known
            ? LLBar(value: value.toDouble(), max: max!.toDouble(), color: color)
            : LLBar(value: 0, max: 1, color: color),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.st, required this.rule});
  final StageProgress st;
  final StateRuleSet rule;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            st.met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: st.met ? LL.success : LL.borderStrong,
          ),
          const SizedBox(width: LL.s2),
          Expanded(
            child: Text(st.stage.label, style: llText(LL.fsSm, weight: FontWeight.w500)),
          ),
          Text(
            '${st.stage.counting == StageCounting.sincePreviousMilestone ? '+' : ''}'
            '${fmtCredit(st.credited, rule, unit: false)} / ${st.stage.totalMinutes == null ? '—' : fmtCredit(st.stage.totalMinutes!, rule)}'
            '${st.stage.nightMinutes != null ? ' · ${fmtCredit(st.night, rule, unit: false)}/${fmtCredit(st.stage.nightMinutes!, rule)} night' : ''}',
            style: llText(LL.fsXs + 1, color: LL.textMuted, numeric: true),
          ),
        ],
      ),
    );
  }
}

/// "Who can supervise" reminder, quoted from the research (or a clear fallback).
class SupervisorReminder extends StatelessWidget {
  const SupervisorReminder({super.key, required this.rule});
  final StateRuleSet rule;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LL.s3),
      decoration: BoxDecoration(
        color: LL.surface2,
        borderRadius: BorderRadius.circular(LL.rMd),
        border: Border.all(color: LL.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_pin_outlined, size: 18, color: LL.textMuted),
          const SizedBox(width: LL.s2),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Supervisor rule: ',
                    style: llText(LL.fsXs + 1, weight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: supervisorText(rule),
                    style: llText(LL.fsXs + 1, color: LL.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
