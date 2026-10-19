import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/services/night_clock.dart';

void main() {
  const clock = NightClock();

  DateTime t(int hour, [int minute = 0, int day = 1]) =>
      DateTime(2026, 3, day, hour, minute);

  test('default night is 6pm to 6am', () {
    expect(clock.isNight(t(17, 59)), isFalse);
    expect(clock.isNight(t(18)), isTrue);
    expect(clock.isNight(t(23)), isTrue);
    expect(clock.isNight(t(5, 59)), isTrue);
    expect(clock.isNight(t(6)), isFalse);
    expect(clock.isNight(t(12)), isFalse);
  });

  test('split 5pm-7pm is one hour day and one hour night', () {
    final split = clock.split(t(17), t(19));
    expect(split.daySeconds, 3600);
    expect(split.nightSeconds, 3600);
  });

  test('split 10pm-2am is all night', () {
    final split = clock.split(t(22), t(2, 0, 2));
    expect(split.nightSeconds, 4 * 3600);
    expect(split.daySeconds, 0);
  });

  test('split 5am-7am is one hour night and one hour day', () {
    final split = clock.split(t(5), t(7));
    expect(split.nightSeconds, 3600);
    expect(split.daySeconds, 3600);
  });

  test('empty range is zero', () {
    final split = clock.split(t(18), t(18));
    expect(split.daySeconds, 0);
    expect(split.nightSeconds, 0);
  });
}
