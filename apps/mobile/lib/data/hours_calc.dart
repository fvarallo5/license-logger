// Credits drives against a state rule set, following the hours math in
// licenselogger-backend/docs/STATE_RULES_SCHEMA.md section 5 (contract v2):
//   1. only SIGNED drives count (pending minutes are reported separately);
//      lessons count only when lessons_count is true
//   2. per local day: day = min(minutes, daily_cap); night/weather clipped to day
//   3. per week (Mon-Sun): week = min(sum of days, weekly_cap); night/weather clipped
//   4. lessons: counted = min(sum, instructor_max_minutes); credited = counted x multiplier;
//      lesson night counts once, up to counted; caps apply to practice only
//   5. totals; AK "challenging" = min(night + weather, credited) per day
//   6. stages and alternatives use the same math over their own window and targets
// Pure Dart (no Flutter), so it can be unit-tested against student_rule_progress().
import 'state_rules.dart';

/// One credited drive for state-rule math. GPS hours already passed HourCredit.
class DriveLog {
  const DriveLog({
    required this.id,
    required this.date,
    required this.startsAt,
    required this.minutes,
    required this.nightMinutes,
    this.weatherMinutes = 0,
    this.miles = 0,
    this.isLesson = false,
    this.signed = true,
  });

  final String id;
  final DateTime date;
  final DateTime startsAt;
  final int minutes;
  final int nightMinutes;
  final int weatherMinutes;
  final double miles;
  final bool isLesson;
  final bool signed;
}

/// One row of `requirements` (keys: total, night, weather, challenging).
class Requirement {
  const Requirement(this.key, this.label, this.required, this.credited, this.pending);
  final String key;
  final String label;
  final int required;
  final int credited;
  final int pending;
  int get remaining => (required - credited).clamp(0, 1 << 30);
  bool get met => credited >= required;
}

class StageProgress {
  const StageProgress(this.stage, this.requirements, {this.windowFrom, this.milestoneAssumed = false});
  final RuleStage stage;
  final List<Requirement> requirements;
  final DateTime? windowFrom; // since_previous_milestone: first day that counts
  final bool milestoneAssumed;
  bool get met => requirements.every((r) => r.met);
  int get credited => requirements.where((r) => r.key == 'total').fold(0, (a, r) => a + r.credited);
  int get night => requirements.where((r) => r.key == 'night').fold(0, (a, r) => a + r.credited);
}

/// Internal running totals (public only so HoursSummary can hold one).
class Tally {
  int credited = 0, night = 0, weather = 0, challenging = 0;
  int instructorRaw = 0, instructorCounted = 0, instructor = 0;
  int trimmed = 0, cappedDays = 0, cappedWeeks = 0;
  final Map<String, int> byDrive = {};
  final List<(DateTime, int, int)> perDay = []; // day, credited, night (practice + lessons that day)
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _weekStart(DateTime d) => _day(d).subtract(Duration(days: d.weekday - 1)); // Monday

Tally _credit(List<DriveLog> signed, StateRuleSet rule) {
  final t = Tally();
  final practice = signed.where((d) => !d.isLesson).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  final lessons = rule.lessonsCount
      ? (signed.where((d) => d.isLesson).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt)))
      : <DriveLog>[];

  // 2. per day
  final days = <DateTime, List<DriveLog>>{};
  for (final d in practice) {
    days.putIfAbsent(_day(d.date), () => []).add(d);
  }
  final dayVals = <DateTime, (int, int, int)>{}; // day -> (credit, night, weather)
  for (final e in days.entries) {
    final sum = e.value.fold(0, (a, d) => a + d.minutes);
    final day = rule.dailyCapMinutes == null ? sum : (sum < rule.dailyCapMinutes! ? sum : rule.dailyCapMinutes!);
    if (day < sum) t.cappedDays++;
    final n = e.value.fold(0, (a, d) => a + d.nightMinutes);
    final w = e.value.fold(0, (a, d) => a + d.weatherMinutes);
    dayVals[e.key] = (day, n < day ? n : day, w < day ? w : day);
  }
  // 3. per week: clip in date order
  if (rule.weeklyCapMinutes != null) {
    final used = <DateTime, int>{};
    final capped = <DateTime>{};
    for (final k in dayVals.keys.toList()..sort()) {
      final wk = _weekStart(k);
      final left = (rule.weeklyCapMinutes! - (used[wk] ?? 0)).clamp(0, 1 << 30);
      var (c, n, w) = dayVals[k]!;
      if (c > left) {
        c = left;
        capped.add(wk);
      }
      used[wk] = (used[wk] ?? 0) + c;
      dayVals[k] = (c, n < c ? n : c, w < c ? w : c);
    }
    t.cappedWeeks = capped.length;
  }
  // per-drive allocation (chronological inside a day) so each drive shows what counted
  for (final e in days.entries) {
    var left = dayVals[e.key]!.$1;
    for (final d in e.value) {
      final c = d.minutes < left ? d.minutes : left;
      left -= c;
      t.byDrive[d.id] = c;
      t.trimmed += d.minutes - c;
    }
  }
  for (final k in dayVals.keys) {
    final (c, n, w) = dayVals[k]!;
    t.credited += c;
    t.night += n;
    t.weather += w;
    final ch = n + w;
    t.challenging += ch < c ? ch : c;
  }
  // 4. instructor lessons
  final lessonNight = <DateTime, int>{};
  final lessonCredit = <DateTime, int>{};
  for (final d in lessons) {
    final cap = rule.instructorMaxMinutes;
    final usable = cap == null ? d.minutes : (cap - t.instructorCounted).clamp(0, d.minutes);
    t.instructorRaw += d.minutes;
    t.instructorCounted += usable;
    final c = (usable * rule.instructorMultiplier).round();
    t.byDrive[d.id] = c;
    t.instructor += c;
    final n = d.nightMinutes < usable ? d.nightMinutes : usable;
    t.night += n;
    lessonNight[_day(d.date)] = (lessonNight[_day(d.date)] ?? 0) + n;
    lessonCredit[_day(d.date)] = (lessonCredit[_day(d.date)] ?? 0) + c;
  }
  t.credited += t.instructor;
  for (final k in {...dayVals.keys, ...lessonCredit.keys}.toList()..sort()) {
    t.perDay.add((k, (dayVals[k]?.$1 ?? 0) + (lessonCredit[k] ?? 0), (dayVals[k]?.$2 ?? 0) + (lessonNight[k] ?? 0)));
  }
  return t;
}

class HoursSummary {
  HoursSummary._({
    required this.rule,
    required this.alternative,
    required this.tally,
    required this.raw,
    required this.pending,
    required this.miles,
    required this.practiceCount,
    required this.requirements,
    required this.stages,
  });
  final StateRuleSet rule;
  final RuleAlternative? alternative;
  final Tally tally;
  final int raw; // practice minutes driven (signed + pending)
  final int pending; // unsigned practice minutes (not credited yet)
  final double miles;
  final int practiceCount;
  final List<Requirement> requirements; // only targets that aren't null
  final List<StageProgress> stages;

  int get credited => tally.credited;
  int get night => tally.night;
  int get weather => tally.weather;
  int get challenging => tally.challenging;
  int get instructor => tally.instructor;
  int get instructorRaw => tally.instructorRaw;
  int get trimmedByCap => tally.trimmed;
  int get cappedDays => tally.cappedDays;
  int get cappedWeeks => tally.cappedWeeks;
  Map<String, int> get byDrive => tally.byDrive;

  Requirement? req(String key) => requirements.where((r) => r.key == key).firstOrNull;
  int? get totalTarget => req('total')?.required;
  int? get nightTarget => req('night')?.required;
  int? get weatherTarget => (req('weather') ?? req('challenging'))?.required;
  int get weatherCredited => rule.weatherCountsNight ? challenging : weather;

  int creditedFor(DriveLog d) => byDrive[d.id] ?? 0;
  int? get remaining => req('total')?.remaining;
  double? get fraction => totalTarget == null ? null : (credited / totalTarget!).clamp(0.0, 1.0);
  bool get totalDone => req('total')?.met ?? false;
  bool get allMet => requirements.isNotEmpty && requirements.every((r) => r.met) && stages.every((s) => s.met);
}

List<Requirement> _reqs(
  StateRuleSet rule,
  int? total,
  int? night,
  int? weather,
  Tally t,
  int pending,
  int pendingNight,
) => [
  if (total != null) Requirement('total', 'Total supervised driving', total, t.credited, pending),
  if (night != null) Requirement('night', 'At night', night, t.night, pendingNight),
  if (weather != null)
    rule.weatherCountsNight
        ? Requirement('challenging', 'Challenging conditions', weather, t.challenging, 0)
        : Requirement('weather', 'In inclement weather', weather, t.weather, 0),
];

/// [isSigned] defaults to the drive's own flag; AppState passes its in-session sign-offs.
/// [alternativeKey] is students.rule_alternative (null = base rule).
HoursSummary computeHours(
  List<DriveLog> drives,
  StateRuleSet rule, {
  bool Function(DriveLog)? isSigned,
  String? alternativeKey,
}) {
  final signedFn = isSigned ?? (d) => d.signed;
  final signed = drives.where(signedFn).toList();
  final unsignedPractice = drives.where((d) => !d.isLesson && !signedFn(d));
  final t = _credit(signed, rule);
  final alt = rule.alternatives.where((a) => a.key == alternativeKey).firstOrNull;
  final practice = drives.where((d) => !d.isLesson);

  final requirements = (rule.isUnconfirmed || rule.noMinimum || (alt?.replacesHours ?? false))
      ? <Requirement>[]
      : _reqs(
          rule,
          alt?.totalMinutes ?? rule.totalMinutes,
          alt?.nightMinutes ?? rule.nightMinutes,
          alt?.weatherMinutes ?? rule.weatherMinutes,
          t,
          unsignedPractice.fold(0, (a, d) => a + d.minutes),
          unsignedPractice.fold(0, (a, d) => a + d.nightMinutes),
        );

  // 6. stages
  final stages = <StageProgress>[];
  final metOn = <String, DateTime>{};
  for (final st in rule.stages) {
    Tally st0;
    DateTime? from;
    var assumed = false;
    if (st.counting == StageCounting.sincePreviousMilestone) {
      from = metOn[st.milestone]; // the app has no milestone table yet -> date the previous stage was met
      assumed = true;
      st0 = from == null ? Tally() : _credit(signed.where((d) => !_day(d.date).isBefore(from!)).toList(), rule);
    } else {
      st0 = t;
    }
    final reqs = _reqs(rule, st.totalMinutes, st.nightMinutes, st.weatherMinutes, st0, 0, 0);
    stages.add(StageProgress(st, reqs, windowFrom: from, milestoneAssumed: assumed && from != null));
    // when was this stage met? (cumulative day by day)
    var c = 0, n = 0;
    for (final (day, dc, dn) in st0.perDay) {
      if (from != null && day.isBefore(from)) continue;
      c += dc;
      n += dn;
      if (c >= (st.totalMinutes ?? 0) && n >= (st.nightMinutes ?? 0)) {
        metOn[st.key] = day;
        break;
      }
    }
  }

  return HoursSummary._(
    rule: rule,
    alternative: alt,
    tally: t,
    raw: practice.fold(0, (a, d) => a + d.minutes),
    pending: unsignedPractice.fold(0, (a, d) => a + d.minutes),
    miles: practice.fold(0.0, (a, d) => a + d.miles),
    practiceCount: practice.length,
    requirements: requirements,
    stages: stages,
  );
}

/// "12.4 h" or "744 min" depending on the state's log unit.
String fmtCredit(int minutes, StateRuleSet rule, {bool unit = true}) {
  if (rule.logUnit == 'minutes') {
    final s = minutes.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return unit ? '$s min' : s;
  }
  final h = (minutes / 60 * 10).round() / 10;
  final s = h == h.roundToDouble() && h >= 10 ? h.toStringAsFixed(0) : h.toStringAsFixed(1);
  return unit ? '$s h' : s;
}
