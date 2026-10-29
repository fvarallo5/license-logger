import '../models/lesson.dart';

class NightClock {
  const NightClock({
    this.nightStartsMinutes = 18 * 60,
    this.nightEndsMinutes = 6 * 60,
  });

  final int nightStartsMinutes;
  final int nightEndsMinutes;

  factory NightClock.fromSettings(AppSettings settings) {
    return NightClock(
      nightStartsMinutes: settings.nightStartsMinutes,
      nightEndsMinutes: settings.nightEndsMinutes,
    );
  }

  bool isNight(DateTime t) {
    final m = t.hour * 60 + t.minute;
    if (nightStartsMinutes == nightEndsMinutes) return false;
    if (nightStartsMinutes > nightEndsMinutes) {
      return m >= nightStartsMinutes || m < nightEndsMinutes;
    }
    return m >= nightStartsMinutes && m < nightEndsMinutes;
  }

  /// Split [start, end) into day vs night seconds using local wall clock.
  ({int daySeconds, int nightSeconds}) split(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return (daySeconds: 0, nightSeconds: 0);
    var cursor = start;
    var night = 0;
    while (cursor.isBefore(end)) {
      final next = _nextBoundary(cursor);
      final sliceEnd = next.isBefore(end) ? next : end;
      final secs = sliceEnd.difference(cursor).inSeconds;
      if (isNight(cursor)) {
        night += secs;
      }
      cursor = sliceEnd;
    }
    final total = end.difference(start).inSeconds;
    return (daySeconds: total - night, nightSeconds: night);
  }

  DateTime _nextBoundary(DateTime t) {
    final midnight = DateTime(t.year, t.month, t.day);
    final startB = midnight.add(Duration(minutes: nightStartsMinutes));
    final endB = midnight.add(Duration(minutes: nightEndsMinutes));
    final candidates = <DateTime>[
      if (startB.isAfter(t)) startB,
      if (endB.isAfter(t)) endB,
      midnight.add(const Duration(days: 1)),
    ]..sort();
    return candidates.first;
  }
}
