import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:license_logger/services/autodetect_service.dart';
import 'package:license_logger/services/battery_mode.dart';

Position _pos({
  required double lat,
  required double lng,
  required DateTime time,
  double speed = -1,
  double accuracy = 10,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: time,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 1,
  );
}

void main() {
  test('estimateSpeedMps uses reported speed when valid', () {
    final now = DateTime.now();
    final p = _pos(lat: 0, lng: 0, time: now, speed: 10);
    expect(AutoDetectService.estimateSpeedMps(p, null), 10);
  });

  test('estimateSpeedMps derives speed when device reports 0 but position moved', () {
    final t0 = DateTime.utc(2026, 7, 1, 12, 0, 0);
    final t1 = t0.add(const Duration(seconds: 10));
    // ~111 m north in 10s ≈ 11 m/s
    final prev = _pos(lat: 0, lng: 0, time: t0, speed: 0);
    final curr = _pos(lat: 0.001, lng: 0, time: t1, speed: 0);
    final speed = AutoDetectService.estimateSpeedMps(curr, prev);
    expect(speed, greaterThan(8));
    expect(speed, lessThan(15));
  });

  test('mpsToMph converts correctly', () {
    expect(AutoDetectService.mpsToMph(4.0), closeTo(8.95, 0.1));
  });

  test('real car-link quickens start; stitch stays long while linked', () {
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {},
    );
    expect(svc.debugStartConfirmSeconds, BatteryMode.balanced.startConfirmSeconds);
    expect(svc.debugMinStartDistanceMeters, BatteryMode.balanced.minStartDistanceMeters);
    expect(svc.debugStitchHold, AutoDetectService.postTripCooldown);
    svc.setCarLinked(true);
    expect(svc.debugStartConfirmSeconds, lessThan(BatteryMode.balanced.startConfirmSeconds));
    expect(svc.debugStartConfirmSeconds, greaterThanOrEqualTo(8));
    expect(svc.debugMinStartDistanceMeters, lessThan(BatteryMode.balanced.minStartDistanceMeters));
    expect(svc.debugMinStartDistanceMeters, greaterThanOrEqualTo(30));
    expect(svc.debugStitchHold, const Duration(seconds: 45));
    svc.dispose();
  });

  test('balanced GPS filters match soft-launch tuning', () {
    expect(BatteryMode.balanced.startSpeedMps, 4.0);
    expect(BatteryMode.balanced.minStartDistanceMeters, 60);
    expect(BatteryMode.balanced.confirmDistanceFilter, 30);
    expect(BatteryMode.balanced.idleLocationSettings.distanceFilter, 100);
    expect(BatteryMode.balanced.activeLocationSettings.distanceFilter, 25);
    expect(BatteryMode.balanced.idleIntervalSeconds, 20);
    expect(BatteryMode.balanced.activeIntervalSeconds, 4);
    expect(BatteryMode.balanced.idleParkSleepAfterSeconds, 90);
    expect(BatteryMode.batterySaver.idleLocationSettings.distanceFilter, 150);
    expect(BatteryMode.batterySaver.idleParkSleepAfterSeconds, 60);
  });

  test('native idle wake skips keep-awake and sleeps GPS without a dart peek', () async {
    expect(BatteryMode.balanced.idleNativeSleepAfterSeconds, 25);
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {},
    );
    svc.setNativeIdleWakeEnabled(true);
    expect(svc.keepAwakeActive, isFalse);
    svc.setCarLinked(true);
    expect(svc.keepAwakeActive, isFalse);

    await svc.debugSleepNow();
    expect(svc.gpsAsleep, isTrue);
    expect(svc.debugHasIdleStream, isFalse);
    expect(svc.statusLabel, contains('sleeping'));

    svc.setAppBackgrounded(true);
    expect(svc.gpsAsleep, isTrue);
    expect(svc.debugHasIdleStream, isFalse);

    svc.wakeFromNative('significant_change');
    expect(svc.gpsAsleep, isFalse);
    expect(svc.powerStats.lastWakeReason, 'significant_change');
    svc.dispose();
  });

  test('car unlink sleeps idle GPS when native wake is on and we look parked', () async {
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {},
    );
    svc.setNativeIdleWakeEnabled(true);
    svc.setCarLinked(true);
    svc.debugMarkMonitoring();
    final now = DateTime.now();
    svc.debugHandleIdlePosition(
      _pos(lat: 40.0, lng: -74.0, time: now, speed: 0.2),
    );
    expect(svc.gpsAsleep, isFalse);
    svc.setCarLinked(false);
    await Future<void>.delayed(Duration.zero);
    expect(svc.gpsAsleep, isTrue);
    expect(svc.debugHasIdleStream, isFalse);
    svc.dispose();
  });

  test('balanced park confirm is 120s and a crawl does not end the trip', () async {
    expect(BatteryMode.balanced.stopConfirmSeconds, 120);
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.pauseForActiveTrip();
    final armedAt = DateTime.now();
    // ~4 mph: above the park crawl, under the old 4.5 mph cutoff.
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: armedAt, speed: 1.8),
      tripMiles: 2,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(minutes: 4)),
      ),
      isFalse,
    );
    expect(ended, 0);

    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: armedAt, speed: 0.2),
      tripMiles: 2,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(seconds: 119)),
      ),
      isFalse,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(seconds: 121)),
      ),
      isFalse,
    );
    expect(svc.debugPendingEnd, isTrue);
    expect(ended, 0);
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(seconds: 121 + 45)),
      ),
      isTrue,
    );
    expect(ended, 1);
    svc.dispose();
  });

  test('car-linked park still holds 45s before auto-end', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.setCarLinked(true);
    svc.pauseForActiveTrip();
    final armedAt = DateTime.now();
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: armedAt, speed: 0.2),
      tripMiles: 2,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(seconds: 121)),
      ),
      isFalse,
    );
    expect(svc.debugPendingEnd, isTrue);
    expect(ended, 0);
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(seconds: 121 + 12)),
      ),
      isFalse,
    );
    expect(ended, 0);
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(seconds: 121 + 45)),
      ),
      isTrue,
    );
    expect(ended, 1);
    svc.dispose();
  });

  test('unlink after a linked trip uses 12s stitch', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.setCarLinked(true);
    svc.pauseForActiveTrip();
    final armedAt = DateTime.now();
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: armedAt, speed: 0.2),
      tripMiles: 2,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(seconds: 121)),
      ),
      isFalse,
    );
    expect(svc.debugPendingEnd, isTrue);
    expect(svc.debugStitchHold, const Duration(seconds: 45));
    svc.setCarLinked(false);
    expect(svc.debugStitchHold, const Duration(seconds: 12));
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(seconds: 121 + 12)),
      ),
      isTrue,
    );
    expect(ended, 1);
    svc.dispose();
  });

  test('balanced GPS silence failsafe is 210s', () {
    expect(BatteryMode.balanced.gpsSilenceFailsafeSeconds, 210);
    expect(AutoDetectService.absoluteGpsSilenceSeconds, 300);
    expect(AutoDetectService.rollingSilenceGiveUpSeconds, 720);
  });

  test('releaseEndLatch allows another auto-end after stuck fire', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.pauseForActiveTrip();
    final armedAt = DateTime.now();
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: armedAt, speed: 0.2),
      tripMiles: 2,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(seconds: 301)),
      ),
      isTrue,
    );
    expect(ended, 1);
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(seconds: 302)),
      ),
      isFalse,
    );
    svc.releaseEndLatch();
    expect(
      svc.tickParkWatchdog(
        tripMiles: 2,
        clock: armedAt.add(const Duration(seconds: 303)),
      ),
      isTrue,
    );
    expect(ended, 2);
    svc.dispose();
  });

  test('soft silence ends mature trip when last sample was slow', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.pauseForActiveTrip();
    final armedAt = DateTime.now();
    expect(
      svc.tickParkWatchdog(
        tripMiles: 5,
        clock: armedAt.add(const Duration(seconds: 151)),
      ),
      isFalse,
    );
    expect(svc.debugPendingEnd, isFalse);
    expect(
      svc.tickParkWatchdog(
        tripMiles: 5,
        clock: armedAt.add(const Duration(seconds: 211)),
      ),
      isFalse,
    );
    expect(svc.debugPendingEnd, isTrue);
    expect(ended, 0);
    expect(
      svc.tickParkWatchdog(
        tripMiles: 5,
        clock: armedAt.add(const Duration(seconds: 211 + 45)),
      ),
      isTrue,
    );
    expect(ended, 1);
    svc.dispose();
  });

  test('walk-to-end after park beats the 120s park window', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.pauseForActiveTrip();
    final armedAt = DateTime.now();
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: armedAt, speed: 0.2),
      tripMiles: 5,
      walking: true,
    );
    expect(ended, 0);
    // Trip must be mature (60s) before walk-to-end arms.
    expect(
      svc.tickParkWatchdog(
        tripMiles: 5,
        walking: true,
        clock: armedAt.add(const Duration(seconds: 61)),
      ),
      isFalse,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 5,
        walking: true,
        clock: armedAt.add(const Duration(seconds: 61 + 75)),
      ),
      isFalse,
    );
    expect(svc.debugPendingEnd, isTrue);
    expect(
      svc.tickParkWatchdog(
        tripMiles: 5,
        walking: true,
        clock: armedAt.add(const Duration(seconds: 61 + 75 + 45)),
      ),
      isTrue,
    );
    expect(ended, 1);
    svc.dispose();
  });

  test('walk-to-end does not fire on still (not walking) at 76s', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.pauseForActiveTrip();
    final armedAt = DateTime.now();
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: armedAt, speed: 0.2),
      tripMiles: 5,
      walking: false,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 5,
        walking: false,
        clock: armedAt.add(const Duration(seconds: 76)),
      ),
      isFalse,
    );
    expect(ended, 0);
    svc.dispose();
  });

  test('walk-to-end does not fire while still rolling', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.pauseForActiveTrip();
    final armedAt = DateTime.now();
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: armedAt, speed: 20),
      tripMiles: 5,
      walking: true,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 5,
        walking: true,
        clock: armedAt.add(const Duration(seconds: 76)),
      ),
      isFalse,
    );
    expect(ended, 0);
    svc.dispose();
  });

  test('soft silence does not end when last sample was fast', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.pauseForActiveTrip();
    final armedAt = DateTime.now();
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: armedAt, speed: 20.0), // ~45 mph
      tripMiles: 5,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 5,
        clock: armedAt.add(const Duration(seconds: 151)),
      ),
      isFalse,
    );
    expect(ended, 0);
    // Rolling last-fix: cellular gaps must not end the trip.
    expect(
      svc.tickParkWatchdog(
        tripMiles: 5,
        clock: armedAt.add(const Duration(seconds: 301)),
      ),
      isFalse,
    );
    expect(ended, 0);
    svc.dispose();
  });

  test('rolling GPS silence does not end a moving trip', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.pauseForActiveTrip();
    final t0 = DateTime.now();
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: t0, speed: 25),
      tripMiles: 9.8,
      clock: t0,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 9.8,
        clock: t0.add(const Duration(seconds: 400)),
      ),
      isFalse,
    );
    expect(ended, 0);
    svc.dispose();
  });

  test('pending end stitches if motion resumes during hold', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.pauseForActiveTrip();
    final t0 = DateTime.now();
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: t0, speed: 0.2),
      tripMiles: 2,
      clock: t0,
    );
    expect(
      svc.tickParkWatchdog(tripMiles: 2, clock: t0.add(const Duration(seconds: 121))),
      isFalse,
    );
    expect(svc.debugPendingEnd, isTrue);
    svc.evaluateActiveTrip(
      _pos(lat: 40.002, lng: -74.0, time: t0.add(const Duration(seconds: 130)), speed: 12),
      tripMiles: 2,
      clock: t0.add(const Duration(seconds: 130)),
    );
    expect(svc.debugPendingEnd, isFalse);
    expect(ended, 0);
    svc.dispose();
  });

  test('young 0.4 mi hop does not auto-end', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.pauseForActiveTrip();
    final t0 = DateTime.utc(2026, 7, 1, 12);
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: t0, speed: 0.2),
      tripMiles: 0.4,
      clock: t0,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 0.4,
        clock: t0.add(const Duration(seconds: 180)),
      ),
      isFalse,
    );
    expect(ended, 0);
    svc.dispose();
  });

  test('highway silence with recent high speed does not soft-end', () async {
    var ended = 0;
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {
        ended++;
      },
    );
    svc.pauseForActiveTrip();
    final t0 = DateTime.utc(2026, 7, 1, 12);
    svc.evaluateActiveTrip(
      _pos(lat: 40.0, lng: -74.0, time: t0, speed: 25),
      tripMiles: 23.3,
      clock: t0,
    );
    expect(
      svc.tickParkWatchdog(
        tripMiles: 23.3,
        clock: t0.add(const Duration(seconds: 160)),
      ),
      isFalse,
    );
    expect(ended, 0);
    svc.dispose();
  });
}
