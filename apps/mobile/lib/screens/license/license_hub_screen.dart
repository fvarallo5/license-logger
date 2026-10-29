import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/hours_calc.dart';
import '../../data/state_rules.dart';
import '../../format.dart';
import '../../screens/license/generate_log_screen.dart';
import '../../screens/profile_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ll_widgets.dart';
import '../../widgets/requirements_card.dart';
import '../../widgets/rule_text.dart';
import '../../widgets/test_ready_card.dart';
import '../../state/app_state.dart';

/// License hub: path, state forms, resources, test-ready checklist.
class LicenseHubScreen extends StatelessWidget {
  const LicenseHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final j = app.jurisdiction;
    final rule = app.ruleSet;
    final sum = app.hoursSummary;
    final s = app.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(LL.s4, 0, LL.s4, LL.s6),
      children: [
        LLTopBar(
          center: Text('License', style: llText(LL.fsLg, weight: FontWeight.w600)),
          trailing: _StateChip(
            code: j?.stateCode ?? (s.stateName.isEmpty ? '—' : s.stateName),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen(editing: true)),
            ),
          ),
        ),
        const SizedBox(height: LL.s2),
        if (j != null && rule != null) ...[
          _StateStrip(j: j, rule: rule, permitIssued: s.permitIssued),
          if (rule.pendingChangeOn != null) ...[
            const SizedBox(height: LL.s3),
            LLCard(
              outline: LL.accent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.event_note_outlined, size: 20, color: LL.warning),
                  const SizedBox(width: LL.s2),
                  Expanded(
                    child: Text(
                      'Coming ${fmtDateLong(rule.pendingChangeOn!)}: ${rule.pendingChangeNote}',
                      style: llText(LL.fsSm, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: LL.s3),
          _PathCard(j: j, rule: rule, sum: sum, permitIssued: s.permitIssued, driverEdDone: s.driverEdDone),
          const SizedBox(height: LL.s3),
          RequirementsCard(
            j: j,
            rule: rule,
            sum: sum ?? computeHours(const [], rule),
            permitIssued: s.permitIssued,
            compact: true,
            showSupervisor: true,
          ),
          const SizedBox(height: LL.s5),
          Padding(
            padding: const EdgeInsets.fromLTRB(LL.s1, 0, LL.s1, LL.s2),
            child: Text('OFFICIAL FORMS', style: llLabel()),
          ),
          if (rule.forms.isEmpty)
            LLCard(
              child: Text(
                'No downloadable form for ${j.stateName} in our research. ${rule.otherRules}',
                style: llText(LL.fsSm, color: LL.textMuted, height: 1.45),
              ),
            )
          else
            for (final (i, f) in rule.forms.indexed) ...[
              _FormCard(form: f, j: j, rule: rule, primary: i == 0),
              const SizedBox(height: LL.s3),
            ],
          const SizedBox(height: LL.s2),
          Padding(
            padding: const EdgeInsets.fromLTRB(LL.s1, 0, LL.s1, LL.s2),
            child: Text('RESOURCES', style: llLabel()),
          ),
          LLCard(
            padding: const EdgeInsets.symmetric(horizontal: LL.s4, vertical: LL.s1),
            child: Column(
              children: [
                for (final (i, r) in j.resources.indexed)
                  _ResourceRow(r: r, last: i == j.resources.length - 1),
              ],
            ),
          ),
        ] else
          LLCard(
            child: Text(
              'Pick your state in profile so we can load hour rules, forms, and the path to a license.',
              style: llText(LL.fsSm, color: LL.textMuted, height: 1.45),
            ),
          ),
        const SizedBox(height: LL.s5),
        Padding(
          padding: const EdgeInsets.fromLTRB(LL.s1, 0, LL.s1, LL.s2),
          child: Text('ROAD TEST', style: llLabel()),
        ),
        const TestReadyCard(),
        const SizedBox(height: LL.s3),
        LLButton(
          'Generate my filled log',
          kind: BtnKind.secondary,
          icon: Icons.description_outlined,
          expand: true,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GenerateLogScreen()),
          ),
        ),
      ],
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.code, this.onTap});
  final String code;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LL.surface,
      shape: const StadiumBorder(side: BorderSide(color: LL.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 16, color: LL.primary),
              const SizedBox(width: 4),
              Text(code, style: llText(LL.fsSm, weight: FontWeight.w600, mono: true)),
              if (onTap != null) const Icon(Icons.expand_more_rounded, size: 18, color: LL.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateStrip extends StatelessWidget {
  const _StateStrip({required this.j, required this.rule, required this.permitIssued});
  final Jurisdiction j;
  final StateRuleSet rule;
  final DateTime? permitIssued;

  @override
  Widget build(BuildContext context) {
    return LLCard(
      hero: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen(editing: true)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: LL.text, borderRadius: BorderRadius.circular(LL.rMd)),
            child: Text(
              j.stateCode,
              style: llText(LL.fsLg, weight: FontWeight.w700, color: LL.surface, mono: true),
            ),
          ),
          const SizedBox(width: LL.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(j.stateName, style: llText(LL.fsLg, weight: FontWeight.w600)),
                Text(
                  permitIssued == null
                      ? 'Add the day you got your permit'
                      : 'Permit issued ${fmtDateLong(permitIssued!)}'
                          '${j.ruleSets.length > 1 ? ' · rule v${rule.version}' : ''}',
                  style: llText(LL.fsSm, color: LL.textMuted, numeric: true),
                ),
              ],
            ),
          ),
          if (rule.isUnconfirmed)
            const LLBadge('Unconfirmed', kind: BadgeKind.warn)
          else if (rule.status == RuleStatus.partiallyVerified)
            const LLBadge('Partly verified', kind: BadgeKind.neutral),
          const Icon(Icons.chevron_right_rounded, color: LL.textMuted),
        ],
      ),
    );
  }
}

enum _StepState { done, current, todo }

class _PathStep {
  const _PathStep(this.title, this.detail, this.state, {this.icon});
  final String title;
  final String detail;
  final _StepState state;
  final IconData? icon;
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.j,
    required this.rule,
    required this.sum,
    required this.permitIssued,
    required this.driverEdDone,
  });
  final Jurisdiction j;
  final StateRuleSet rule;
  final HoursSummary? sum;
  final DateTime? permitIssued;
  final bool driverEdDone;

  @override
  Widget build(BuildContext context) {
    final hoursDone = sum?.totalDone ?? false;
    final form = rule.forms.isEmpty ? null : rule.forms.first;
    final steps = <_PathStep>[
      _PathStep(
        'Learner permit',
        permitIssued == null
            ? 'Add the issue date in profile'
            : 'Issued ${fmtDateLong(permitIssued!)}${rule.permitHold != null ? ' · state rule: “${rule.permitHold}”' : ''}',
        permitIssued == null ? _StepState.current : _StepState.done,
        icon: Icons.badge_outlined,
      ),
      _PathStep(
        'Supervised practice',
        sum == null || sum!.totalTarget == null
            ? ruleSummary(rule)
            : '${fmtCredit(sum!.credited, rule)} of ${fmtCredit(sum!.totalTarget!, rule)}'
                '${sum!.nightTarget != null ? ' · ${fmtCredit(sum!.night, rule, unit: false)}/${fmtCredit(sum!.nightTarget!, rule)} night' : ''}',
        hoursDone || rule.noMinimum ? _StepState.done : _StepState.current,
        icon: Icons.route_outlined,
      ),
      if (rule.driverEd != null)
        _PathStep(
          'Driver education',
          '${j.stateName} rules mention: “${rule.driverEd}”',
          driverEdDone ? _StepState.done : _StepState.current,
          icon: Icons.school_outlined,
        ),
      _PathStep(
        form == null ? 'Hours sign-off' : 'Sign-off: ${_short(form)}',
        [
          rule.certificationOnly ? 'Parent/guardian certifies the hours' : 'Signed log goes with your application',
          ?notaryText(rule),
        ].join(' · '),
        hoursDone ? _StepState.current : _StepState.todo,
        icon: Icons.draw_outlined,
      ),
      const _PathStep(
        'Road test',
        'Book with your state when the checklist is done',
        _StepState.todo,
        icon: Icons.flag_outlined,
      ),
      const _PathStep(
        'Provisional license',
        'Drive on your own, with your state’s limits',
        _StepState.todo,
        icon: Icons.workspace_premium_outlined,
      ),
    ];
    final done = steps.where((s) => s.state == _StepState.done).length;
    return LLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Your path to a license', style: llText(LL.fsMd, weight: FontWeight.w600)),
              ),
              Text(
                '$done of ${steps.length}',
                style: llText(LL.fsSm, weight: FontWeight.w600, color: LL.textMuted, numeric: true),
              ),
            ],
          ),
          const SizedBox(height: LL.s2),
          LLBar(value: done.toDouble(), max: steps.length.toDouble(), height: 6),
          const SizedBox(height: LL.s3),
          for (final (i, st) in steps.indexed) _StepRow(step: st, last: i == steps.length - 1),
        ],
      ),
    );
  }

  static String _short(StateForm f) {
    final c = f.formNumber.replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ').trim();
    return c.isNotEmpty ? c : (f.formName.length > 28 ? '${f.formName.substring(0, 27)}…' : f.formName);
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last});
  final _PathStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (Color c, Widget dot) = switch (step.state) {
      _StepState.done => (
          LL.success,
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: LL.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 16, color: LL.surface),
          ),
        ),
      _StepState.current => (
          LL.primary,
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: LL.surface,
              shape: BoxShape.circle,
              border: Border.all(color: LL.primary, width: 2),
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: LL.primary, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      _StepState.todo => (
          LL.borderStrong,
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: LL.surface,
              shape: BoxShape.circle,
              border: Border.all(color: LL.border, width: 2),
            ),
          ),
        ),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                dot,
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: step.state == _StepState.done ? LL.success.withValues(alpha: .4) : LL.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: LL.s3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : LL.s3, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: llText(
                      LL.fsSm + 1,
                      weight: FontWeight.w600,
                      color: step.state == _StepState.todo ? LL.textMuted : LL.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.detail,
                    style: llText(LL.fsXs + 1, color: step.state == _StepState.current ? c : LL.textMuted, height: 1.35),
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

class _FormCard extends StatelessWidget {
  const _FormCard({required this.form, required this.j, required this.rule, this.primary = false});
  final StateForm form;
  final Jurisdiction j;
  final StateRuleSet rule;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final unconfirmed = rule.isUnconfirmed;
    final notary = notaryText(rule);
    return LLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 48,
                decoration: BoxDecoration(
                  color: LL.surface2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: LL.border),
                ),
                child: const Icon(Icons.description_outlined, color: LL.danger, size: 22),
              ),
              const SizedBox(width: LL.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(form.formName, style: llText(LL.fsSm + 1, weight: FontWeight.w600, height: 1.3)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (form.formNumber.isNotEmpty)
                          Text(form.formNumber, style: llText(LL.fsXs + 1, mono: true, color: LL.textMuted)),
                        LLBadge(_typeLabel(form), kind: BadgeKind.neutral, dot: false),
                        if (unconfirmed)
                          const LLBadge('Unconfirmed', kind: BadgeKind.warn)
                        else if (form.linkVerified)
                          const LLBadge('Link checked', kind: BadgeKind.pass)
                        else if (form.linkUnverified)
                          const LLBadge('Link not verified', kind: BadgeKind.warn),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (primary) ...[
            const SizedBox(height: LL.s3),
            _Note(icon: Icons.phone_iphone_rounded, text: digitalLogText(rule, j.stateName)),
            if (notary != null) ...[
              const SizedBox(height: LL.s2),
              _Note(icon: Icons.verified_user_outlined, text: notary, color: LL.warning),
            ],
          ],
          const SizedBox(height: LL.s3),
          if (primary && !j.isUnconfirmed) ...[
            LLButton(
              'Generate my filled log',
              icon: Icons.description_outlined,
              expand: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GenerateLogScreen()),
              ),
            ),
            const SizedBox(height: LL.s2),
          ],
          LLButton(
            'Open official PDF',
            kind: BtnKind.secondary,
            icon: Icons.open_in_new_rounded,
            expand: true,
            onPressed: form.pdfUrl == null || unconfirmed
                ? null
                : () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Open in browser', style: llText(LL.fsLg, weight: FontWeight.w600)),
                        content: SelectableText(form.pdfUrl!, style: llText(LL.fsSm, mono: true)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  static String _typeLabel(StateForm f) {
    if (f.isAlternate) return 'Other form';
    return switch (f.formType) {
      FormType.fullLog => f.formTypeDetail.contains('certification') ? 'Log + certification' : 'Driving log',
      FormType.certification => 'Certification',
      FormType.none => 'Form',
      FormType.unconfirmed => 'Unconfirmed',
    };
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.color = LL.textMuted});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: LL.s2),
          Expanded(
            child: Text(
              text,
              style: llText(LL.fsXs + 1, color: color == LL.textMuted ? LL.textMuted : LL.text, height: 1.4),
            ),
          ),
        ],
      );
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.r, required this.last});
  final StateLink r;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final icon = switch (r.kind) {
      'handbook' => Icons.menu_book_outlined,
      'parent_guide' => Icons.family_restroom_outlined,
      'gdl_page' => Icons.gavel_outlined,
      _ => Icons.public_rounded,
    };
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Open in browser', style: llText(LL.fsLg, weight: FontWeight.w600)),
          content: SelectableText(r.url, style: llText(LL.fsSm, mono: true)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: LL.s3),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: LL.border)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: LL.primary),
            const SizedBox(width: LL.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.label, style: llText(LL.fsSm + 1, weight: FontWeight.w600)),
                  Text(
                    '${r.host} · checked ${r.lastChecked == null ? '—' : fmtDateLong(r.lastChecked!)}',
                    style: llText(LL.fsXs, color: LL.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (r.status != null && !r.verified) const LLBadge('Not verified', kind: BadgeKind.warn),
            const Icon(Icons.open_in_new_rounded, size: 16, color: LL.textMuted),
          ],
        ),
      ),
    );
  }
}
