import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/services/hour_credit.dart';

void main() {
  test('zero miles credits zero seconds', () {
    expect(
      HourCredit.creditedSeconds(durationSeconds: 3600, miles: 0),
      0,
    );
  });

  test('miles cap hours at 15 mph', () {
    expect(
      HourCredit.creditedSeconds(durationSeconds: 3600, miles: 7.5),
      1800,
    );
    expect(
      HourCredit.creditedSeconds(durationSeconds: 3600, miles: 15),
      3600,
    );
    expect(
      HourCredit.creditedSeconds(durationSeconds: 1800, miles: 20),
      1800,
    );
  });

  test('night hours scale with the mile cap', () {
    expect(
      HourCredit.creditedNightSeconds(
        durationSeconds: 7200,
        nightSeconds: 3600,
        miles: 15,
      ),
      1800,
    );
  });

  test('min miles for a clock is 15 mph', () {
    expect(HourCredit.minMilesFor(const Duration(hours: 2)), 30);
    expect(HourCredit.minMilesFor(const Duration(minutes: 30)), 7.5);
  });

  test('trips under 15 mi/h or 0.5 mi do not log', () {
    expect(
      HourCredit.canLog(durationSeconds: 3600, miles: 14.9),
      isFalse,
    );
    expect(
      HourCredit.canLog(durationSeconds: 3600, miles: 15),
      isTrue,
    );
    expect(
      HourCredit.canLog(durationSeconds: 30, miles: 0.2),
      isFalse,
    );
    expect(
      HourCredit.canLog(durationSeconds: 120, miles: 0.5),
      isTrue,
    );
  });
}
