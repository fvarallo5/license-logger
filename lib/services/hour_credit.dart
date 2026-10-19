/// Permit hours only log when GPS miles support 15 miles per hour of clock.
///
/// A 1-hour drive needs 15 miles to save. Sitting on Start does not log.
class HourCredit {
  static const minAverageMph = 15.0;

  /// Parking-lot GPS noise. Anything shorter is discarded.
  static const minSaveMiles = 0.5;

  static const tooShortMessage = 'Trip Too Short To Save';

  static int creditedSeconds({
    required int durationSeconds,
    required double miles,
  }) {
    if (durationSeconds <= 0 || miles <= 0) return 0;
    final byMiles = miles / minAverageMph * 3600;
    final capped = byMiles.floor();
    if (capped <= 0) return 0;
    return capped < durationSeconds ? capped : durationSeconds;
  }

  static int creditedNightSeconds({
    required int durationSeconds,
    required int nightSeconds,
    required double miles,
  }) {
    final credited = creditedSeconds(
      durationSeconds: durationSeconds,
      miles: miles,
    );
    if (durationSeconds <= 0 || credited <= 0) return 0;
    final night = nightSeconds.clamp(0, durationSeconds);
    return (night * credited / durationSeconds).round().clamp(0, credited);
  }

  static double hours({
    required int durationSeconds,
    required double miles,
  }) =>
      creditedSeconds(durationSeconds: durationSeconds, miles: miles) / 3600;

  static double minMilesFor(Duration elapsed) {
    if (elapsed.inSeconds <= 0) return minSaveMiles;
    return elapsed.inSeconds / 3600 * minAverageMph;
  }

  static double milesNeeded({
    required int durationSeconds,
    required double miles,
  }) {
    final need = minMilesFor(Duration(seconds: durationSeconds));
    final floor = need < minSaveMiles ? minSaveMiles : need;
    final left = floor - miles;
    return left < 0 ? 0 : left;
  }

  static bool canLog({
    required int durationSeconds,
    required double miles,
  }) {
    if (miles + 0.0001 < minSaveMiles) return false;
    final need = minMilesFor(Duration(seconds: durationSeconds));
    return miles + 0.05 >= need;
  }
}
