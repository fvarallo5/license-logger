import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/models/lesson.dart';
import 'package:license_logger/services/hour_credit.dart';
import 'package:license_logger/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AppState fresh({AppSettings? settings}) {
    return AppState(
      store: MemoryStore(settings: settings ?? sampleStudent()),
      gps: FakeTripTracker(),
    );
  }

  test('start and end a lesson', () async {
    final state = fresh();
    addTearDown(state.dispose);
    await state.load();

    await state.startLesson(meet: 'School lot');
    expect(state.live, isNotNull);
    expect(state.live!.meet, 'School lot');
    expect(state.live!.status, LessonStatus.inLesson);

    await state.endLesson();
    expect(state.live, isNull);
    expect(state.lessons, isEmpty);
    expect(state.error, HourCredit.tooShortMessage);
  });

  test('a trip with enough miles saves', () async {
    final gps = FakeTripTracker()..seedMiles(16);
    final state = AppState(store: MemoryStore(), gps: gps);
    addTearDown(state.dispose);
    await state.load();
    await state.startLesson();
    await state.endLesson();
    expect(state.lessons, hasLength(1));
    expect(state.lessons.first.status, LessonStatus.done);
    expect(state.error, isNull);
  });

  test('idle clock does not credit permit hours without miles', () async {
    final state = fresh();
    addTearDown(state.dispose);
    await state.load();
    final skipped = await state.logManual(
      start: DateTime(2026, 3, 1, 16),
      end: DateTime(2026, 3, 1, 17),
      miles: 0,
    );
    expect(skipped, isFalse);
    expect(state.lessons, isEmpty);
    expect(state.error, HourCredit.tooShortMessage);

    final saved = await state.logManual(
      start: DateTime(2026, 3, 1, 18),
      end: DateTime(2026, 3, 1, 19),
      miles: 15,
    );
    expect(saved, isTrue);
    expect(state.lessons.first.hours, closeTo(1, 0.001));
  });

  test('manual log splits night hours after 6pm', () async {
    final state = fresh();
    addTearDown(state.dispose);
    await state.load();
    await state.logManual(
      start: DateTime(2026, 3, 1, 17),
      end: DateTime(2026, 3, 1, 19),
      miles: 40,
    );
    expect(state.lessons.single.hours, 2);
    expect(state.lessons.single.nightHours, 1);
    expect(state.totalHours, 2);
    expect(state.totalNightHours, 1);
  });

  test('period pills filter the list, not lifetime hours', () async {
    final state = fresh();
    addTearDown(state.dispose);
    await state.load();
    await state.logManual(
      start: DateTime(2020, 1, 1, 10),
      end: DateTime(2020, 1, 1, 12),
      miles: 40,
    );
    await state.logManual(
      start: DateTime.now().subtract(const Duration(minutes: 90)),
      end: DateTime.now().subtract(const Duration(minutes: 30)),
      miles: 20,
    );
    expect(state.totalHours, closeTo(3, 0.02));
    state.setPeriod(HoursPeriod.week);
    expect(state.periodLessons, hasLength(1));
    state.setPeriod(HoursPeriod.all);
    expect(state.periodLessons, hasLength(2));
  });

  test('auto-track starts idle monitoring', () async {
    final state = fresh(settings: const AppSettings(autoDetect: true));
    addTearDown(state.dispose);
    await state.load();
    expect(state.autoDetect.isMonitoring, isTrue);
    await state.autoDetect.stopMonitoring();
  });

  test('vehicle gate sleeps idle GPS until in-vehicle', () async {
    final state = fresh(settings: const AppSettings(autoDetect: true));
    addTearDown(state.dispose);
    await state.load();
    expect(state.autoDetect.isMonitoring, isTrue);

    state.activity.gateEnabled = true;
    state.activity.available = true;
    state.activity.inVehicle = false;
    await state.updateSettings(state.settings);
    expect(state.autoDetect.isMonitoring, isFalse);
    expect(state.isWaitingOnPowerGate, isTrue);

    state.activity.inVehicle = true;
    await state.updateSettings(state.settings);
    expect(state.autoDetect.isMonitoring, isTrue);

    state.activity.inVehicle = false;
    state.activity.available = false;
    await state.updateSettings(state.settings);
    expect(state.autoDetect.isMonitoring, isTrue);
    await state.autoDetect.stopMonitoring();
  });
}
