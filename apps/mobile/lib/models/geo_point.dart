import 'dart:math' as math;

/// Simple lat/lng without map package coupling.
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);

  List<double> toJson() => [lat, lng];

  factory GeoPoint.fromJson(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      return GeoPoint((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
    }
    if (raw is Map) {
      return GeoPoint(
        (raw['lat'] as num).toDouble(),
        (raw['lng'] as num? ?? raw['lon'] as num).toDouble(),
      );
    }
    throw FormatException('Invalid GeoPoint: $raw');
  }

  /// Downsample a path (keeps endpoints + evenly spaced midpoints).
  static List<GeoPoint> sparsify(List<GeoPoint> route, {int maxPoints = 40}) {
    if (route.length <= maxPoints) return List.unmodifiable(route);
    if (maxPoints < 2) return [route.first, route.last];

    final out = <GeoPoint>[route.first];
    final step = (route.length - 1) / (maxPoints - 1);
    for (var i = 1; i < maxPoints - 1; i++) {
      out.add(route[(i * step).round()]);
    }
    out.add(route.last);
    return out;
  }

  static double distanceMeters(GeoPoint a, GeoPoint b) {
    const r = 6371000.0;
    final lat1 = a.lat * math.pi / 180;
    final lat2 = b.lat * math.pi / 180;
    final dLat = lat2 - lat1;
    final dLng = (b.lng - a.lng) * math.pi / 180;
    final h = _hav(dLat) + math.cos(lat1) * math.cos(lat2) * _hav(dLng);
    return 2 * r * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  static double _hav(double rad) {
    final s = math.sin(rad / 2);
    return s * s;
  }
}

/// Result of a finished GPS session (miles + path for map / audit).
class TripTrackResult {
  final double miles;
  final List<GeoPoint> route;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const TripTrackResult({
    required this.miles,
    required this.route,
    this.startedAt,
    this.endedAt,
  });

  GeoPoint? get start => route.isEmpty ? null : route.first;
  GeoPoint? get end => route.isEmpty ? null : route.last;

  List<GeoPoint> sparseRoute({int maxPoints = 40}) =>
      GeoPoint.sparsify(route, maxPoints: maxPoints);
}
