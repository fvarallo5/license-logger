import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';
import '../models/lesson.dart';
import '../services/activity_recognition_service.dart';
import '../services/autodetect_service.dart';
import '../services/battery_mode.dart';
import '../services/battery_service.dart';
import '../services/hour_credit.dart';
import '../services/idle_wake_service.dart';
import '../services/lesson_store.dart';
import '../services/night_clock.dart';
import '../services/trip_tracker.dart';

enum HoursPeriod { week, month, all }

class AppState extends ChangeNotifier {
  AppState({
    LessonStore? store,
    TripTracker? gps,
    ActivityRecognitionService? activity,
    IdleWakeService? idleWake,
    BatteryService? battery,
    AutoDetectService? autoDetect,
  })  : _store = store ?? LessonStore(),
        gps = gps ?? TripTracker(),
        activity = activity ?? ActivityRecognitionService(),
        _idleWake = idleWake ?? IdleWakeService(),
        battery = battery ?? BatteryService() {
    final created = autoDetect ??
        AutoDetectService(
          onTripStarted: _handleAutoLessonStarted,
          onTripEnded: () => _handleAutoLessonEnded(),
        );
    this.autoDetect = created;
    this.activity.addListener(_onPowerGateChanged);
    created.addListener(_safeNotify);
    this.gps.onPosition = _onGpsPosition;
    _idleWake.onWake = (reason) {
      if (this.activity.inVehicle) created.wakeFromNative('motion');
      created.wakeFromNative(reason);
      unawaited(_syncAutoDetectMonitoring());
    };
  }

  final LessonStore _store;
  final TripTracker gps;
  final ActivityRecognitionService activity;
  final IdleWakeService _idleWake;
  final BatteryService battery;
  late final AutoDetectService autoDetect;

  AppSettings settings = const AppSettings();
  List<Lesson> lessons = [];
  Lesson? live;
  Duration liveElapsed = Duration.zero;
  String? error;
  bool loaded = false;
  HoursPeriod period = HoursPeriod.all;
  bool appInForeground = true;
  String? lastAutoDetectMessage;
  DriveKind nextKind = DriveKind.practice;

  Timer? _tick;
  bool _stopInFlight = false;

  NightClock get clock => NightClock.fromSettings(settings);

  double get liveMiles => gps.currentMiles;

  int get liveCreditedSeconds => HourCredit.creditedSeconds(
        durationSeconds: liveElapsed.inSeconds,
        miles: liveMiles,
      );

  double get liveCreditedHours => liveCreditedSeconds / 3600;

  String get headerStatus {
    if (live != null) return 'Driving';
    if (!settings.autoDetect) return 'Ready';
    if (isWaitingOnPowerGate) return 'Waiting';
    if (autoDetect.isMonitoring) return 'Watching';
    return 'Ready';
  }

  List<GeoPoint> get liveRoute => gps.currentRoute;

  void setNextKind(DriveKind kind) {
    nextKind = kind;
    notifyListeners();
  }

  double get totalHours =>
      lessons.where((l) => l.status == LessonStatus.done).fold(0.0, (s, l) => s + l.hours) +
      (live == null ? 0 : liveCreditedHours);

  double get totalNightHours =>
      lessons.where((l) => l.status == LessonStatus.done).fold(0.0, (s, l) => s + l.nightHours) +
      (live == null ? 0 : liveCreditedNightSeconds / 3600);

  int get liveCreditedNightSeconds {
    if (live == null) return 0;
    return HourCredit.creditedNightSeconds(
      durationSeconds: liveElapsed.inSeconds,
      nightSeconds: _liveNightSeconds,
      miles: liveMiles,
    );
  }

  int get _liveNightSeconds {
    if (live == null) return 0;
    return clock.split(live!.start, live!.start.add(liveElapsed)).nightSeconds;
  }

  bool get _activityAllowsWatch {
    if (!activity.gateEnabled) return true;
    // Simulator / devices without a motion coprocessor: GPS-only.
    if (!activity.available) return true;
    if (activity.allowsAutoDetectWatch) return true;
    if (activity.isConfidentOnFoot) return false;
    if (!appInForeground) return true;
    return false;
  }

  bool get powerGatesAllowWatch => _activityAllowsWatch;

  bool get isWaitingOnPowerGate =>
      settings.autoDetect && live == null && !powerGatesAllowWatch;

  String? get powerGateWaitLabel {
    if (!isWaitingOnPowerGate) return null;
    return activity.statusLabel;
  }

  bool get _isWalkingForAutoEnd {
    if (!activity.hasPermission) return false;
    return activity.activity == 'walking' ||
        activity.activity == 'on_foot' ||
        activity.activity == 'running';
  }

  String get autoTrackCaption {
    if (!settings.autoDetect) return '';
    if (live != null) {
      return autoDetect.phase == AutoDetectPhase.confirmingStop
          ? 'Parked — ending drive…'
          : 'Stopped ~2 minutes ends an auto drive.';
    }
    if (isWaitingOnPowerGate) {
      return powerGateWaitLabel ?? 'Waiting for a vehicle…';
    }
    if (lastAutoDetectMessage != null && lastAutoDetectMessage!.isNotEmpty) {
      return lastAutoDetectMessage!;
    }
    return autoDetect.statusLabel;
  }

  List<Lesson> get periodLessons {
    final now = DateTime.now();
    final start = switch (period) {
      HoursPeriod.week => now.subtract(Duration(days: now.weekday - 1)),
      HoursPeriod.month => DateTime(now.year, now.month, 1),
      HoursPeriod.all => DateTime(2000),
    };
    final from = DateTime(start.year, start.month, start.day);
    return lessons.where((l) => !l.start.isBefore(from) && l.status == LessonStatus.done).toList();
  }

  Future<void> load() async {
    try {
      settings = await _store.loadSettings();
      lessons = await _store.loadLessons();
      await battery.load();
      await activity.load();
      activity.setExitHold(battery.mode.vehicleGateExitHold);
      live = lessons.where((l) => l.isOpen).firstOrNull;
      if (live != null) {
        liveElapsed = DateTime.now().difference(live!.start);
        await gps.restoreSession(batteryMode: battery.mode);
        autoDetect.pauseForActiveTrip();
        _beginClock();
        gps.onPosition = _onGpsPosition;
      }
      await _syncAutoDetectMonitoring();
    } catch (_) {
      error = 'Could not load lessons.';
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await _store.saveSettings(next);
    await _syncAutoDetectMonitoring();
    notifyListeners();
  }

  Future<void> toggleChecklist(String id) async {
    final s = settings;
    final next = switch (id) {
      'driverEd' => s.copyWith(driverEdDone: !s.driverEdDone),
      'written' => s.copyWith(writtenTestDone: !s.writtenTestDone),
      'docs' => s.copyWith(documentsReady: !s.documentsReady),
      _ => s,
    };
    if (identical(next, s)) return;
    await updateSettings(next);
  }

  Future<void> setBatteryMode(BatteryMode mode) async {
    await battery.setMode(mode);
    activity.setExitHold(mode.vehicleGateExitHold);
    await autoDetect.applyMode(mode);
    if (gps.isTracking) await gps.applyBatteryMode(mode);
    notifyListeners();
  }

  Future<void> setVehicleGate(bool enabled) async {
    await activity.setGateEnabled(enabled);
    await _syncAutoDetectMonitoring();
    notifyListeners();
  }

  Future<void> requestMotionPermission() async {
    await activity.requestSystemPrompt();
    if (settings.autoDetect) {
      await activity.start();
      await _syncAutoDetectMonitoring();
    }
    notifyListeners();
  }

  Future<void> startLesson({bool auto = false, String meet = ''}) async {
    if (live != null) return;
    error = null;
    final perm = auto
        ? await gps.requestBackgroundPermission()
        : await gps.requestForegroundPermission();
    if (perm != null) {
      error = perm;
      notifyListeners();
      if (auto) {
        autoDetect.cancelPendingStart(detail: perm);
        return;
      }
    }
    final lesson = Lesson(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      start: DateTime.now(),
      status: LessonStatus.inLesson,
      autoStarted: auto,
      meet: meet,
      kind: nextKind,
    );
    live = lesson;
    liveElapsed = Duration.zero;
    lessons = [lesson, ...lessons];
    await _store.saveLessons(lessons);
    await autoDetect.stopMonitoring();
    autoDetect.pauseForActiveTrip();
    await gps.start(
      background: true,
      autoStarted: auto,
      batteryMode: battery.mode,
    );
    gps.onPosition = _onGpsPosition;
    _beginClock();
    lastAutoDetectMessage = auto ? 'Auto drive in progress' : null;
    notifyListeners();
  }

  Future<void> endLesson({bool auto = false}) async {
    if (live == null || _stopInFlight) {
      if (live == null) autoDetect.resumeAfterTrip();
      return;
    }
    _stopInFlight = true;
    final open = live!;
    final end = DateTime.now();
    final split = clock.split(open.start, end);
    var miles = gps.currentMiles;
    var route = List<GeoPoint>.from(open.route);
    try {
      final result = await gps.stop();
      if (result.miles > 0) miles = result.miles;
      if (result.route.isNotEmpty) {
        route = GeoPoint.sparsify(result.route, maxPoints: 40);
      }
    } catch (_) {}
    final durationSeconds = end.difference(open.start).inSeconds;
    live = null;
    liveElapsed = Duration.zero;
    _tick?.cancel();
    if (!HourCredit.canLog(durationSeconds: durationSeconds, miles: miles)) {
      lessons = lessons.where((l) => l.id != open.id).toList();
      await _store.saveLessons(lessons);
      error = HourCredit.tooShortMessage;
      lastAutoDetectMessage = HourCredit.tooShortMessage;
      autoDetect.resumeAfterTrip();
      _stopInFlight = false;
      await _syncAutoDetectMonitoring();
      notifyListeners();
      return;
    }
    final done = open.copyWith(
      end: end,
      durationSeconds: durationSeconds,
      nightSeconds: split.nightSeconds,
      miles: miles,
      status: LessonStatus.done,
      autoEnded: auto,
      route: route,
    );
    lessons = lessons.map((l) => l.id == done.id ? done : l).toList();
    await _store.saveLessons(lessons);
    autoDetect.resumeAfterTrip();
    error = null;
    if (auto) {
      lastAutoDetectMessage = 'Auto-saved ${miles.toStringAsFixed(1)} mi';
    }
    _stopInFlight = false;
    await _syncAutoDetectMonitoring();
    notifyListeners();
  }

  Future<bool> logManual({
    required DateTime start,
    required DateTime end,
    double miles = 0,
    String meet = '',
    String notes = '',
    DriveKind kind = DriveKind.practice,
  }) async {
    final durationSeconds = end.difference(start).inSeconds;
    if (!HourCredit.canLog(durationSeconds: durationSeconds, miles: miles)) {
      error = HourCredit.tooShortMessage;
      notifyListeners();
      return false;
    }
    final split = clock.split(start, end);
    final lesson = Lesson(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      start: start,
      end: end,
      durationSeconds: end.difference(start).inSeconds,
      nightSeconds: split.nightSeconds,
      miles: miles,
      meet: meet,
      notes: notes,
      status: LessonStatus.done,
      kind: kind,
    );
    lessons = [lesson, ...lessons]..sort((a, b) => b.start.compareTo(a.start));
    await _store.saveLessons(lessons);
    error = null;
    notifyListeners();
    return true;
  }

  Future<void> deleteLesson(String id) async {
    if (live?.id == id) {
      live = null;
      _tick?.cancel();
      await gps.stop();
      autoDetect.resumeAfterTrip();
    }
    lessons = lessons.where((l) => l.id != id).toList();
    await _store.saveLessons(lessons);
    notifyListeners();
  }

  void setPeriod(HoursPeriod next) {
    period = next;
    notifyListeners();
  }

  void setAppBackgrounded(bool backgrounded) {
    appInForeground = !backgrounded;
    autoDetect.setAppBackgrounded(backgrounded);
    unawaited(_syncAutoDetectMonitoring());
  }

  void _safeNotify() {
    notifyListeners();
  }

  void _onPowerGateChanged() {
    if (activity.inVehicle) autoDetect.wakeFromNative('motion');
    unawaited(_syncAutoDetectMonitoring());
  }

  void _onGpsPosition(Position position) {
    if (live == null || !gps.isTracking) return;
    if (!gps.isAutoStarted || !settings.autoDetect) return;
    if (!autoDetect.isTripActive) autoDetect.pauseForActiveTrip();
    autoDetect.evaluateActiveTrip(
      position,
      tripMiles: gps.currentMiles,
      walking: _isWalkingForAutoEnd,
    );
    gps.setParkSampling(autoDetect.wantsParkSampling);
    notifyListeners();
  }

  void _beginClock() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (live == null) return;
      liveElapsed = DateTime.now().difference(live!.start);
      if (gps.isAutoStarted && settings.autoDetect) {
        autoDetect.tickParkWatchdog(
          tripMiles: gps.currentMiles,
          walking: _isWalkingForAutoEnd,
        );
        gps.setParkSampling(autoDetect.wantsParkSampling);
      }
      notifyListeners();
    });
  }

  Future<void> _handleAutoLessonStarted() async {
    if (live != null || gps.isTracking || _stopInFlight) {
      autoDetect.cancelPendingStart(detail: 'Lesson already active');
      return;
    }
    lastAutoDetectMessage = 'Drive confirmed — starting lesson';
    notifyListeners();
    await startLesson(auto: true);
    if (live == null) {
      lastAutoDetectMessage = error ?? 'Could not start auto lesson GPS';
      autoDetect.resumeAfterTrip();
      await _syncAutoDetectMonitoring();
      notifyListeners();
    }
  }

  Future<void> _handleAutoLessonEnded({bool force = false}) async {
    if (live == null || _stopInFlight) {
      if (live == null) {
        autoDetect.resumeAfterTrip();
      } else {
        autoDetect.releaseEndLatch();
      }
      return;
    }
    if (!force && !gps.isAutoStarted) {
      autoDetect.releaseEndLatch();
      return;
    }
    await endLesson(auto: true);
  }

  Future<void> _syncAutoDetectMonitoring() async {
    final shouldWatch =
        settings.autoDetect && live == null && powerGatesAllowWatch;
    if (shouldWatch) {
      if (appInForeground) {
        final permError = await gps.requestBackgroundPermission();
        if (permError != null) {
          error = permError;
          notifyListeners();
          return;
        }
      }
      final wakeOk = await _idleWake.start();
      autoDetect.setNativeIdleWakeEnabled(wakeOk);
      if (!kIsWeb && Platform.isIOS) unawaited(activity.start());
      if (!autoDetect.isMonitoring) {
        await autoDetect.startMonitoring(mode: battery.mode);
      }
    } else {
      unawaited(_idleWake.stop());
      autoDetect.setNativeIdleWakeEnabled(false);
      if (live == null && !autoDetect.holdWatchDespiteGate) {
        await autoDetect.stopMonitoring();
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    activity.removeListener(_onPowerGateChanged);
    autoDetect.removeListener(_safeNotify);
    _tick?.cancel();
    gps.dispose();
    autoDetect.dispose();
    activity.dispose();
    unawaited(_idleWake.stop());
    super.dispose();
  }
}
