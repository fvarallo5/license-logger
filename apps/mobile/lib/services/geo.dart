import 'dart:math' as math;

class Geo {
  static const _earthMiles = 3958.8;

  static double miles(double lat1, double lon1, double lat2, double lon2) {
    const p = math.pi / 180;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 2 * _earthMiles * math.asin(math.sqrt(a));
  }

  static double mphFromMps(double mps) => mps * 2.236936;
}
