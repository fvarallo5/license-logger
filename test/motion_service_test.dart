import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/services/motion_service.dart';

void main() {
  test('vehicle latch holds 45s after leaving automotive', () {
    final latch = VehicleLatch(hold: const Duration(seconds: 45));
    final t0 = DateTime(2026, 1, 1, 12);
    expect(latch.apply(rawInVehicle: true, now: t0), isTrue);
    expect(latch.apply(rawInVehicle: false, now: t0.add(const Duration(seconds: 10))), isTrue);
    expect(latch.apply(rawInVehicle: false, now: t0.add(const Duration(seconds: 54))), isTrue);
    expect(latch.apply(rawInVehicle: false, now: t0.add(const Duration(seconds: 55))), isFalse);
  });

  test('automotive sample re-arms the latch', () {
    final latch = VehicleLatch(hold: const Duration(seconds: 45));
    final t0 = DateTime(2026, 1, 1, 12);
    latch.apply(rawInVehicle: true, now: t0);
    latch.apply(rawInVehicle: false, now: t0.add(const Duration(seconds: 40)));
    expect(latch.apply(rawInVehicle: true, now: t0.add(const Duration(seconds: 41))), isTrue);
    expect(latch.apply(rawInVehicle: false, now: t0.add(const Duration(seconds: 50))), isTrue);
  });

  test('native map sets in-vehicle through the latch', () async {
    final motion = MotionService(useNative: false);
    await motion.applyNative({
      'available': true,
      'permission': true,
      'activity': 'in_vehicle',
      'confidence': 85,
      'inVehicle': true,
    });
    expect(motion.inVehicle, isTrue);
    expect(motion.hasPermission, isTrue);
    expect(motion.activityLabel, 'In vehicle');
  });
}
