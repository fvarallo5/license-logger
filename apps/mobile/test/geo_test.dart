import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/services/geo.dart';

void main() {
  test('same point is zero miles', () {
    expect(Geo.miles(40.0, -75.0, 40.0, -75.0), 0);
  });

  test('one degree of latitude is about 69 miles', () {
    final miles = Geo.miles(40.0, -75.0, 41.0, -75.0);
    expect(miles, closeTo(69.1, 0.5));
  });

  test('mps to mph', () {
    expect(Geo.mphFromMps(0), 0);
    expect(Geo.mphFromMps(5.36448), closeTo(12.0, 0.01));
  });
}
