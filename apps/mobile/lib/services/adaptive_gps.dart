/// Garmin-style in-trip sampling: fewer GPS requests on a stable heading.
///
/// Changing what we *store* does not save battery. Changing the live
/// `distanceFilter` / interval does. Highway straights are almost a line;
/// map-match fills the rest at save.
enum GpsSampleBand { park, urban, highway }

class AdaptiveGps {
  AdaptiveGps._();

  /// ~25 mph — typical highway / fast arterial.
  static const highwayEnterMps = 11.2;

  /// ~20 mph — leave highway band (hysteresis).
  static const highwayExitMps = 8.9;

  static const enterHeadingDeg = 12.0;
  static const leaveHeadingDeg = 25.0;

  static const highwayDistanceFilter = 80;
  static const highwayIntervalSeconds = 8;
  static const parkDistanceFilter = 12;
  static const parkIntervalSeconds = 5;

  static double headingDeltaDeg(double a, double b) {
    var d = (a - b).abs() % 360;
    if (d > 180) d = 360 - d;
    return d;
  }

  static GpsSampleBand band({
    required bool parkSampling,
    required bool mature,
    required double speedMps,
    required double headingDeltaDeg,
    GpsSampleBand current = GpsSampleBand.urban,
  }) {
    if (parkSampling) return GpsSampleBand.park;
    if (!mature) return GpsSampleBand.urban;
    if (speedMps >= highwayEnterMps && headingDeltaDeg <= enterHeadingDeg) {
      return GpsSampleBand.highway;
    }
    if (current == GpsSampleBand.highway &&
        speedMps >= highwayExitMps &&
        headingDeltaDeg <= leaveHeadingDeg) {
      return GpsSampleBand.highway;
    }
    return GpsSampleBand.urban;
  }
}
