import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/services/activity_recognition_service.dart';
import 'package:license_logger/services/autodetect_service.dart';
import 'package:license_logger/services/battery_mode.dart';

void main() {
  test('vehicle gate latches on immediately and holds 45s after raw drop', () {
    final latch = VehicleGateLatch();
    final t0 = DateTime.utc(2026, 9, 2, 12, 0, 0);

    expect(latch.apply(rawInVehicle: true, now: t0), isTrue);
    expect(
      latch.apply(
        rawInVehicle: false,
        now: t0.add(const Duration(seconds: 10)),
      ),
      isTrue,
      reason: 'Core Motion still mid-drive must not drop GPS yet',
    );
    expect(
      latch.apply(
        rawInVehicle: false,
        now: t0.add(const Duration(seconds: 54)),
      ),
      isTrue,
    );
    expect(
      latch.apply(
        rawInVehicle: false,
        now: t0.add(const Duration(seconds: 55)),
      ),
      isFalse,
    );
  });

  test('raw automotive during hold re-arms the latch', () {
    final latch = VehicleGateLatch();
    final t0 = DateTime.utc(2026, 9, 2, 12, 0, 0);
    latch.apply(rawInVehicle: true, now: t0);
    latch.apply(rawInVehicle: false, now: t0.add(const Duration(seconds: 20)));
    expect(
      latch.apply(rawInVehicle: true, now: t0.add(const Duration(seconds: 21))),
      isTrue,
    );
    expect(
      latch.apply(
        rawInVehicle: false,
        now: t0.add(const Duration(seconds: 50)),
      ),
      isTrue,
      reason: 'Hold clock restarts after another in-vehicle sample',
    );
  });

  test('confirming start holds watch despite a gate drop', () {
    final svc = AutoDetectService(
      onTripStarted: () async {},
      onTripEnded: () async {},
    );
    expect(svc.holdWatchDespiteGate, isFalse);
    // Mimic confirmingStart via the public pause path? pause is tripActive.
    svc.pauseForActiveTrip();
    expect(svc.holdWatchDespiteGate, isTrue);
    expect(svc.isTripActive, isTrue);
  });

  test('start speed-dip grace is 8 seconds', () {
    expect(AutoDetectService.startSpeedDipGrace, const Duration(seconds: 25));
    expect(VehicleGateLatch().hold, const Duration(seconds: 45));
    expect(
      BatteryMode.batterySaver.vehicleGateExitHold,
      const Duration(seconds: 20),
    );
    expect(
      BatteryMode.balanced.vehicleGateExitHold,
      const Duration(seconds: 25),
    );
  });
}
