import '../data/hours_calc.dart';
import '../data/state_rules.dart';

/// One-line summary of a rule, built only from the rule data.
String ruleSummary(StateRuleSet r) {
  if (r.noRuleOnFile) return 'No rule on file for this permit date';
  if (r.isUnconfirmed) return r.totalMinutes == null ? 'Hour rule unconfirmed' : 'Partly unconfirmed';
  if (r.noMinimum) return 'No supervised-hours minimum';
  final parts = <String>[];
  if (r.totalMinutes != null) {
    parts.add(
      r.nightMinutes != null
          ? '${fmtCredit(r.totalMinutes!, r)} incl. ${fmtCredit(r.nightMinutes!, r)} night'
          : '${fmtCredit(r.totalMinutes!, r)} · night not specified',
    );
  } else {
    parts.add('Total unconfirmed');
  }
  if (r.weatherMinutes != null) {
    parts.add(
      r.weatherCountsNight
          ? '${fmtCredit(r.weatherMinutes!, r)} in challenging conditions'
          : '+ ${fmtCredit(r.weatherMinutes!, r)} bad weather',
    );
  }
  if (r.dailyCapMinutes != null) parts.add('max ${fmtCredit(r.dailyCapMinutes!, r)}/day');
  if (r.weeklyCapMinutes != null) parts.add('max ${fmtCredit(r.weeklyCapMinutes!, r)}/week');
  if (r.lessonsCount && r.instructorMultiplier != 1) parts.add('instructor hours ×${_n(r.instructorMultiplier)}');
  if (r.stages.isNotEmpty) parts.add('${r.stages.length} stages');
  if (r.alternatives.isNotEmpty) {
    parts.add('${r.alternatives.length} other path${r.alternatives.length > 1 ? 's' : ''}');
  }
  return parts.join(' · ');
}

String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Notarization line, using the backend's notarization + notarization_note.
String? notaryText(StateRuleSet r) {
  final note = r.notarizationNote.isEmpty ? '' : ' (${r.notarizationNote})';
  return switch (r.notarization) {
    Notarization.required => 'Notarization required$note.',
    Notarization.ifSignerAbsent => 'Notarize only if the signer can’t be there in person$note.',
    Notarization.notStated =>
      r.isFieldUnconfirmed('notarization') ? 'Notarization: ${r.caveat('notarization') ?? 'unconfirmed'}.' : null,
  };
}

/// How to use the LicenseLogger log with the state (mirrors how_to_use_licenselogger_log).
String digitalLogText(StateRuleSet r, String stateName) {
  final note = r.digitalLogNote.isEmpty ? '' : ' Research note: “${r.digitalLogNote}”.';
  if (r.noRuleOnFile || r.isUnconfirmed) {
    return 'Unconfirmed: our research couldn’t confirm what $stateName accepts. Print, sign and bring the official form.';
  }
  if (r.noMinimum) return '$stateName has no hours log requirement. Your log is for your own records.';
  return switch (r.digitalLog) {
    DigitalLog.accepted => '$stateName accepts a digital or printed log.$note',
    DigitalLog.listedApps =>
      '$stateName accepts only its own form${r.digitalLogApps.isEmpty ? '' : ' or ${r.digitalLogApps.join(', ')}'}. '
          'Use LicenseLogger as your worksheet and copy entries onto the official form.$note',
    DigitalLog.notStated =>
      r.certificationOnly
          ? '$stateName only needs a signed certification of the totals. Your log backs up the signature.$note'
          : 'Our research doesn’t say if $stateName takes digital logs. Copy your entries onto the official form, sign, and bring it.$note',
  };
}

/// Supervisor reminder built from supervisor_min_age / _min_years_licensed / _parent_exempt / _rule.
String supervisorText(StateRuleSet r) {
  if (r.noRuleOnFile || (r.isUnconfirmed && r.supervisorRule.isEmpty)) {
    return 'Unconfirmed. ${r.caveat('supervisor_min_age') ?? 'Check the state handbook.'}';
  }
  final bits = <String>[
    if (r.supervisorMinAge != null) 'at least ${r.supervisorMinAge}',
    if (r.supervisorMinYearsLicensed != null) 'licensed ${_n(r.supervisorMinYearsLicensed!)}+ yr',
  ];
  final head = bits.isEmpty
      ? ''
      : 'Supervisor ${bits.join(', ')}${r.supervisorParentExempt ? ' (licensed parents/guardians excepted)' : ''}. ';
  if (r.supervisorRule.isNotEmpty) return '$head“${r.supervisorRule}”';
  return head.isEmpty ? 'Not listed in our research. Check the handbook.' : head.trim();
}
