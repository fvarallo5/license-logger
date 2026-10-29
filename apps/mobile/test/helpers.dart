import 'package:license_logger/models/geo_point.dart';
import 'package:license_logger/models/lesson.dart';
import 'package:license_logger/services/battery_mode.dart';
import 'package:license_logger/services/lesson_store.dart';
import 'package:license_logger/services/trip_tracker.dart';

AppSettings sampleStudent({bool autoDetect = false}) {
  return AppSettings(
    autoDetect: autoDetect,
    firstName: 'Ava',
    lastName: 'Lopez',
    birthday: DateTime(2010, 6, 15),
    stateName: 'California',
    permitIssued: DateTime(2026, 1, 10),
    hourGoal: 50,
    nightGoal: 10,
  );
}

class MemoryStore extends LessonStore {
  MemoryStore({
    List<Lesson>? lessons,
    AppSettings? settings,
  }) : _lessons = List.of(lessons ?? const []) {
    _settings = settings ?? sampleStudent();
  }

  List<Lesson> _lessons;
  late AppSettings _settings;

  @override
  Future<List<Lesson>> loadLessons() async => List.of(_lessons);

  @override
  Future<void> saveLessons(List<Lesson> lessons) async {
    _lessons = List.of(lessons);
  }

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }
}

/// GPS no-op for unit/widget tests (no Geolocator / EventChannel).
class FakeTripTracker extends TripTracker {
  bool _fakeTracking = false;
  bool _fakeAuto = false;
  double _fakeMiles = 0;

  void seedMiles(double miles) => _fakeMiles = miles;

  @override
  bool get isTracking => _fakeTracking;

  @override
  bool get isAutoStarted => _fakeAuto;

  @override
  double get currentMiles => _fakeMiles;

  @override
  List<GeoPoint> get currentRoute => const [];

  @override
  Future<String?> requestForegroundPermission() async => null;

  @override
  Future<String?> requestBackgroundPermission() async => null;

  @override
  Future<void> start({
    bool background = false,
    bool autoStarted = false,
    BatteryMode batteryMode = BatteryMode.balanced,
  }) async {
    _fakeTracking = true;
    _fakeAuto = autoStarted;
  }

  @override
  Future<TripTrackResult> stop() async {
    _fakeTracking = false;
    _fakeAuto = false;
    final now = DateTime.now();
    final result = TripTrackResult(
      miles: _fakeMiles,
      route: const [],
      startedAt: now,
      endedAt: now,
    );
    _fakeMiles = 0;
    return result;
  }

  @override
  Future<void> restoreSession({
    BatteryMode batteryMode = BatteryMode.balanced,
  }) async {}

  @override
  Future<void> applyBatteryMode(BatteryMode mode) async {}

  @override
  void setParkSampling(bool enabled) {}

  @override
  void dispose() {}
}
