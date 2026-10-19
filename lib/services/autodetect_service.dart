import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/stream_restart_scheduler.dart';
import 'battery_mode.dart';
import 'gps_power_stats.dart';

/// High-level phase for UI status chips.
enum AutoDetectPhase {
  off,
  watching,
  confirmingStart,
  tripActive,
  confirmingStop,
}

/// Speed + distance based driving detection with battery-mode-aware sampling.
///
/// Start requires sustained motion (speed + meters moved), not a single GPS blip.
/// Stop requires sustained stillness with little displacement (parked, not traffic).
class AutoDetectService extends ChangeNotifier {
  AutoDetectService({
    required this.onTripStarted,
    required this.onTripEnded,
    this.onIdleFix,
  });

  final Future<void> Function() onTripStarted;
  final Future<void> Function() onTripEnded;
  /// Idle GPS is running (locked-safe). Used to clear a stuck Live Activity.
  final void Function()? onIdleFix;

  /// Ignore fixes worse than this (meters).
  static const maxAccuracyMeters = 55.0;

  /// If we move this far during a "stop" window, cancel parking detection.
  /// Build 10: looser so urban GPS wander doesn't reset park forever.
  static const stopCancelDistanceMeters = 90.0;

  /// Parked-looking last sample + this long with no GPS → garage / canyon end.
  static const absoluteGpsSilenceSeconds = 300;

  /// Last sample was still driving and GPS has been dead this long (killed
  /// stream / overnight). Cell gaps of a few minutes must not hit this.
  static const rollingSilenceGiveUpSeconds = 720;

  /// After an auto trip ends, ignore new starts briefly (double-fire guard).
  /// Stays 45s even with the car linked so a destination save does not bounce.
  static const postTripCooldown = Duration(seconds: 45);

  /// Stitch after the car radio drops. 12s while still linked ended lights.
  static const postTripCooldownAfterUnlink = Duration(seconds: 12);

  /// Keep idle GPS awake after a save so the next drive can start while locked.
  /// Dart Timers and iOS auto-pause often never resume until the app is opened.
  static const postTripKeepAwake = Duration(minutes: 20);

  /// One slow GPS sample must not cancel start confirmation (lights / noise).
  /// Red lights are often 15–30s — 8s was resetting the whole window.
  static const startSpeedDipGrace = Duration(seconds: 25);

  /// Parked + walking (steps), not still/unknown. Longer than a typical light.
  static const walkToEndHold = Duration(seconds: 75);

  /// Defaults used when a mode is not set (tests / edge).
  static const defaultStartSpeedMps = 5.0;
  static const defaultStopSpeedMps = 1.5;
  static const defaultMinStartDistanceMeters = 120.0;

  StreamSubscription<Position>? _subscription;
  final _restart = StreamRestartScheduler();
  bool _monitoring = false;
  bool _tripActive = false;
  bool _startInFlight = false;
  bool _endInFlight = false;
  DateTime? _drivingSince;
  DateTime? _stoppedSince;
  DateTime? _cooldownUntil;
  DateTime? _tripStartedAt;
  Position? _lastPosition;
  Position? _startAnchor; // first good sample in a start-confirm window
  double _startDistanceMeters = 0;
  Position? _stopAnchor;
  double _stopDistanceMeters = 0;
  Position? _activeAnchor;
  double _activeDistanceMeters = 0;
  /// Last time we saw non-parked motion (for park watchdog when GPS goes quiet).
  DateTime? _lastMovingAt;
  /// Last sample looked parked (watchdog must not end highway trips on GPS silence).
  bool _lastSampleLookedParked = false;
  /// Wall-clock of last usable fix while trip-active (silence failsafe).
  DateTime? _lastAcceptedFixAt;
  BatteryMode _mode = BatteryMode.balanced;
  AutoDetectPhase _phase = AutoDetectPhase.off;
  String? _statusDetail;
  double? _lastSpeedMps;
  DateTime? _idleStillSince;
  Timer? _idleSleepTimer;
  DateTime? _startSpeedDipSince;
  bool _confirmSampling = false;
  DateTime? _walkSince;
  DateTime? _keepAwakeUntil;
  DateTime? _pendingEndSince;
  String? _pendingEndReason;
  DateTime? _lastHighSpeedAt;
  bool _appBackgrounded = false;
  /// Idle GPS often sleeps before the first drive of a session (cold start).
  bool _hadAutoTripThisSession = false;
  /// Real Bluetooth / CarPlay / Android Auto (never inferred from GPS speed).
  /// Linked: quicker start. Still linked: long park + long stitch.
  /// Radio dropped this trip: 12s stitch.
  bool carLinked = false;
  bool _sawCarLinkThisTrip = false;
  /// Native significant-change / motion can restart GPS while locked.
  bool nativeIdleWakeEnabled = false;
  /// Idle high-accuracy stream is off; cheap sensors own the wake.
  bool gpsAsleep = false;
  final GpsPowerStats powerStats = GpsPowerStats();

  double get _startSpeedMps => _mode.startSpeedMps;
  double get _stopSpeedMps => _mode.stopSpeedMps;
  double get _minStartDistanceMeters => carLinked
      ? math.max(30, _mode.minStartDistanceMeters * 0.55)
      : _mode.minStartDistanceMeters;

  int get _startConfirmSeconds => carLinked
      ? math.max(8, (_mode.startConfirmSeconds * 0.55).round())
      : _mode.startConfirmSeconds;

  @visibleForTesting
  int get debugStartConfirmSeconds => _startConfirmSeconds;

  @visibleForTesting
  double get debugMinStartDistanceMeters => _minStartDistanceMeters;

  @visibleForTesting
  bool get debugPendingEnd => _pendingEndSince != null;

  @visibleForTesting
  Duration get debugStitchHold => _stitchHold;

  Duration get _stitchHold {
    if (carLinked) return postTripCooldown;
    if (_sawCarLinkThisTrip) return postTripCooldownAfterUnlink;
    return postTripCooldown;
  }

  /// Last motion above park crawl was this recent. A 0-mph GPS glitch
  /// plus a Bluetooth hop must not force-end a city trip.
  bool get recentlyMoving {
    final t = _lastMovingAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(seconds: 45);
  }

  void setNativeIdleWakeEnabled(bool enabled) {
    nativeIdleWakeEnabled = enabled;
    if (enabled) _keepAwakeUntil = null;
  }

  void setCarLinked(bool linked) {
    final becameLinked = linked && !carLinked;
    final becameUnlinked = !linked && carLinked;
    carLinked = linked;
    if (linked && _tripActive) _sawCarLinkThisTrip = true;
    if (becameLinked) {
      wakeForCarLink();
    } else if (becameUnlinked) {
      _onCarUnlinked();
    }
  }

  /// Car BT / CarPlay came up — cancel idle nap and keep GPS awake so the
  /// first drive can confirm while locked.
  void wakeForCarLink() {
    carLinked = true;
    if (!nativeIdleWakeEnabled) {
      _keepAwakeUntil = DateTime.now().add(const Duration(minutes: 20));
    }
    wakeFromNative('car_link');
  }

  void _onCarUnlinked() {
    if (_tripActive) _sawCarLinkThisTrip = true;
    if (!nativeIdleWakeEnabled) return;
    if (!_monitoring || _tripActive) return;
    if (_phase == AutoDetectPhase.confirmingStart) return;
    final speed = _lastSpeedMps ?? 0;
    if (speed > _stopSpeedMps) return;
    unawaited(_sleepIdleGps());
  }

  /// Restart the confirm stream after a cheap-sensor wake (car, motion, SLC).
  void wakeFromNative(String reason) {
    powerStats.markWake(reason);
    _idleSleepTimer?.cancel();
    _idleSleepTimer = null;
    _idleStillSince = null;
    gpsAsleep = false;
    // First fix after sleep must not inherit driveway→road teleport speed.
    if (!_tripActive) {
      _lastPosition = null;
      _lastSpeedMps = null;
    }
    if (!_monitoring || _tripActive) return;
    if (_subscription != null) return;
    unawaited(_restartStream());
    _setPhase(
      AutoDetectPhase.watching,
      detail: 'Woke · $reason',
    );
  }

  bool get isMonitoring => _monitoring;
  bool get isTripActive => _tripActive;

  /// Tighten GPS while parked so auto-end still gets background samples.
  bool get wantsParkSampling =>
      _tripActive &&
      (_phase == AutoDetectPhase.confirmingStop ||
          _lastSampleLookedParked);

  /// Keep the GPS stream up even if a power gate flickers off.
  bool get holdWatchDespiteGate =>
      _tripActive || _phase == AutoDetectPhase.confirmingStart;
  BatteryMode get mode => _mode;
  AutoDetectPhase get phase => _phase;
  String? get statusDetail => _statusDetail;
  double? get lastSpeedMps => _lastSpeedMps;

  /// Human-readable status for Track tab.
  String get statusLabel {
    switch (_phase) {
      case AutoDetectPhase.off:
        return 'Off';
      case AutoDetectPhase.watching:
        return gpsAsleep
            ? 'GPS sleeping — waiting for car or motion'
            : 'Watching for a drive';
      case AutoDetectPhase.confirmingStart:
        return 'Drive detected — confirming…';
      case AutoDetectPhase.tripActive:
        return 'Lesson in progress';
      case AutoDetectPhase.confirmingStop:
        return 'Parked — ending trip…';
    }
  }

  Future<void> startMonitoring({BatteryMode mode = BatteryMode.balanced}) async {
    _mode = mode;
    if (_monitoring) {
      if (_subscription == null && !_tripActive) {
        await _restartStream();
      }
      return;
    }
    _monitoring = true;
    _tripActive = false;
    _startInFlight = false;
    gpsAsleep = false;
    if (!nativeIdleWakeEnabled && !_hadAutoTripThisSession) {
      _keepAwakeUntil = DateTime.now().add(const Duration(minutes: 45));
    }
    _restart.reset();
    _resetStartWindow();
    _resetStopWindow();
    _resetActiveDistance();
    await _restartStream();
    _setPhase(AutoDetectPhase.watching);
  }

  Future<void> applyMode(BatteryMode mode) async {
    _mode = mode;
    if (_monitoring && !_tripActive && !gpsAsleep) {
      await _restartStream();
    }
  }

  Future<void> _restartStream() async {
    await _subscription?.cancel();
    _restart.cancel();
    final woke = gpsAsleep;
    gpsAsleep = false;
    powerStats.markStreamOn();
    try {
    _subscription = Geolocator.getPositionStream(
      locationSettings: _idleLocationSettings(),
    ).listen(
      (position) {
        _restart.reset();
        _onPosition(position);
      },
      onError: (Object e) {
        _statusDetail = 'Location error — retrying…';
        notifyListeners();
        _scheduleIdleStreamRestart();
      },
      onDone: () {
        if (_monitoring && !_tripActive) _scheduleIdleStreamRestart();
      },
      cancelOnError: false,
    );
    } catch (e) {
      _statusDetail = 'Location error — retrying…';
      _scheduleIdleStreamRestart();
    }
    if (woke) notifyListeners();
  }

  void _scheduleIdleStreamRestart() {
    if (!_monitoring || _tripActive) return;
    if (_restart.exhausted) {
      _statusDetail = 'Location unavailable — check permissions';
      notifyListeners();
      return;
    }
    _restart.schedule(() {
      if (_monitoring && !_tripActive) unawaited(_restartStream());
    });
  }

  /// Background-capable settings so watching continues when the app is not open.
  LocationSettings _idleLocationSettings() {
    final base = _mode.idleLocationSettings;
    final confirming = _confirmSampling ||
        _phase == AutoDetectPhase.confirmingStart;
    final filter =
        confirming ? _mode.confirmDistanceFilter : base.distanceFilter;
    // Confirming a start never pauses. After a trip (and while locked) don't
    // let iOS auto-pause — it often won't resume until TrekTrack is opened.
    final pauseWhenStill = !confirming &&
        _mode.idlePauseLocationUpdatesAutomatically &&
        !_keepGpsAwake;

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: confirming ? LocationAccuracy.high : base.accuracy,
        distanceFilter: filter,
        intervalDuration: Duration(
          seconds: confirming
              ? _mode.activeIntervalSeconds
              : _mode.idleIntervalSeconds,
        ),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'LicenseLogger Auto-track',
          notificationText: 'Watching for drives · ${_mode.label}',
          enableWakeLock: false,
          setOngoing: true,
        ),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: confirming ? LocationAccuracy.high : base.accuracy,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: filter,
        pauseLocationUpdatesAutomatically: pauseWhenStill,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }

    return LocationSettings(
      accuracy: confirming ? LocationAccuracy.high : base.accuracy,
      distanceFilter: filter,
    );
  }

  void _ensureConfirmSampling() {
    if (_confirmSampling || _tripActive) return;
    _confirmSampling = true;
    unawaited(_restartStream());
  }

  void _endConfirmSampling() {
    if (!_confirmSampling) return;
    _confirmSampling = false;
    if (_monitoring && !_tripActive) unawaited(_restartStream());
  }

  void pauseForActiveTrip() {
    _tripActive = true;
    _startInFlight = false;
    _endInFlight = false;
    _tripStartedAt = DateTime.now();
    _lastMovingAt = DateTime.now();
    _lastAcceptedFixAt = DateTime.now();
    _lastSampleLookedParked = false;
    _resetStartWindow();
    _resetStopWindow();
    _resetActiveDistance();
    _cancelPendingEnd();
    _lastHighSpeedAt = null;
    if (carLinked) _sawCarLinkThisTrip = true;
    _setPhase(AutoDetectPhase.tripActive);
  }

  /// Clear a stuck end latch without starting post-trip cooldown.
  /// Used when [onTripEnded] early-returns while GPS is still live.
  void releaseEndLatch() {
    _endInFlight = false;
  }

  /// Abort a start that AppState rejected (e.g. near home place).
  void cancelPendingStart({String? detail}) {
    _tripActive = false;
    _startInFlight = false;
    _endInFlight = false;
    _tripStartedAt = null;
    _resetStartWindow();
    _resetStopWindow();
    _resetActiveDistance();
    if (_monitoring) {
      _setPhase(
        AutoDetectPhase.watching,
        detail: detail ?? 'Start skipped',
      );
    } else {
      _setPhase(AutoDetectPhase.off);
    }
  }

  void resumeAfterTrip() {
    _tripActive = false;
    _startInFlight = false;
    _endInFlight = false;
    _hadAutoTripThisSession = true;
    _sawCarLinkThisTrip = false;
    _tripStartedAt = null;
    _lastMovingAt = null;
    _lastAcceptedFixAt = null;
    _lastSampleLookedParked = false;
    _cancelPendingEnd();
    _lastHighSpeedAt = null;
    final now = DateTime.now();
    _cooldownUntil = now.add(postTripCooldown);
    if (nativeIdleWakeEnabled) {
      _keepAwakeUntil = null;
    } else {
      _keepAwakeUntil = now.add(postTripKeepAwake);
    }
    _idleSleepTimer?.cancel();
    _idleSleepTimer = null;
    _idleStillSince = null;
    _resetStartWindow();
    _resetStopWindow();
    _resetActiveDistance();
    if (_monitoring) {
      _setPhase(AutoDetectPhase.watching, detail: 'Cooldown before next auto-start');
      if (nativeIdleWakeEnabled && !carLinked) {
        unawaited(_sleepIdleGps());
      } else {
        unawaited(_restartStream());
      }
    } else {
      _setPhase(AutoDetectPhase.off);
    }
  }

  /// Locked / another app in front — Dart Timers will not fire.
  void setAppBackgrounded(bool backgrounded) {
    _appBackgrounded = backgrounded;
    if (!backgrounded) {
      if (_monitoring && !_tripActive && _subscription == null) {
        wakeFromNative('app');
      }
      return;
    }
    if (nativeIdleWakeEnabled) {
      // Leave a sleeping stream off; cheap sensors wake us.
      return;
    }
    _idleSleepTimer?.cancel();
    _idleSleepTimer = null;
    if (_monitoring && !_tripActive && _subscription == null) {
      unawaited(_restartStream());
    }
  }

  bool get keepAwakeActive => _keepGpsAwake;

  @visibleForTesting
  void debugHandleIdlePosition(Position position) => _onPosition(position);

  @visibleForTesting
  bool get debugHasIdleStream => _subscription != null;

  @visibleForTesting
  void debugMarkMonitoring() {
    _monitoring = true;
    _phase = AutoDetectPhase.watching;
  }

  @visibleForTesting
  Future<void> debugSleepNow() => _sleepIdleGps();

  bool get _keepGpsAwake {
    final until = _keepAwakeUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  Future<void> stopMonitoring() async {
    _monitoring = false;
    _tripActive = false;
    _startInFlight = false;
    _endInFlight = false;
    _tripStartedAt = null;
    _resetStartWindow();
    _resetStopWindow();
    _resetActiveDistance();
    _lastPosition = null;
    _lastSpeedMps = null;
    _restart.cancel();
    _idleSleepTimer?.cancel();
    _idleSleepTimer = null;
    _idleStillSince = null;
    _confirmSampling = false;
    gpsAsleep = false;
    powerStats.markOff();
    await _subscription?.cancel();
    _subscription = null;
    _setPhase(AutoDetectPhase.off);
  }

  void _onPosition(Position position) {
    if (!_monitoring || _tripActive) return;
    if (!_isUsableFix(position)) return;
    powerStats.markSample();
    onIdleFix?.call();

    final speed = estimateSpeedMps(position, _lastPosition);
    _lastSpeedMps = speed;

    final now = DateTime.now();
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
      _lastPosition = position;
      _statusDetail = 'Cooldown ${(_cooldownUntil!.difference(now).inSeconds)}s';
      notifyListeners();
      return;
    }

    if (speed >= _startSpeedMps) {
      _idleStillSince = null;
      _idleSleepTimer?.cancel();
      _startSpeedDipSince = null;
      _onDrivingSample(position, now, speed);
      _lastPosition = position;
      return;
    }

    // Not driving — clear start window, but ignore a brief GPS/speed dip.
    if (_drivingSince != null) {
      _startSpeedDipSince ??= now;
      if (now.difference(_startSpeedDipSince!) < startSpeedDipGrace) {
        _statusDetail =
            'Confirming · speed dip ${mpsToMph(speed).toStringAsFixed(0)} mph';
        _lastPosition = position;
        notifyListeners();
        return;
      }
      _resetStartWindow();
      _setPhase(AutoDetectPhase.watching);
    }

    if (speed <= _stopSpeedMps) {
      _statusDetail = speed > 0
          ? 'Idle · ${mpsToMph(speed).toStringAsFixed(0)} mph'
          : 'Idle · waiting for motion';
      _maybeParkedSleep(now);
    } else {
      _idleStillSince = null;
      _statusDetail = 'Slow · ${mpsToMph(speed).toStringAsFixed(0)} mph';
    }

    _lastPosition = position;
    notifyListeners();
  }

  /// After parked long enough, drop the high-accuracy stream.
  void _maybeParkedSleep(DateTime now) {
    if (_tripActive || _phase == AutoDetectPhase.confirmingStart) return;
    if (nativeIdleWakeEnabled) {
      if (carLinked) return;
      if (_keepGpsAwake) return;
    } else {
      // Dart Timer never fires while suspended, so don't nap locked.
      if (_appBackgrounded || _keepGpsAwake) return;
    }
    final after = nativeIdleWakeEnabled
        ? _mode.idleNativeSleepAfterSeconds
        : _mode.idleParkSleepAfterSeconds;
    if (after == null) return;
    _idleStillSince ??= now;
    if (now.difference(_idleStillSince!) < Duration(seconds: after)) return;
    if (_idleSleepTimer != null && !nativeIdleWakeEnabled) return;
    unawaited(_sleepIdleGps());
  }

  Future<void> _sleepIdleGps() async {
    await _subscription?.cancel();
    _subscription = null;
    _idleStillSince = null;
    gpsAsleep = true;
    powerStats.markAsleep();
    if (nativeIdleWakeEnabled) {
      _idleSleepTimer?.cancel();
      _idleSleepTimer = null;
      _setPhase(
        AutoDetectPhase.watching,
        detail: 'GPS sleeping — waiting for car or motion',
      );
      return;
    }
    final nap = _mode.idleParkSleepForSeconds;
    _setPhase(
      AutoDetectPhase.watching,
      detail: 'Parked — GPS sleeping ${nap}s',
    );
    _idleSleepTimer?.cancel();
    _idleSleepTimer = Timer(Duration(seconds: nap), () {
      _idleSleepTimer = null;
      gpsAsleep = false;
      if (_monitoring && !_tripActive) unawaited(_restartStream());
    });
  }

  void _onDrivingSample(Position position, DateTime now, double speed) {
    _resetStopWindow();

    if (_drivingSince == null) {
      _drivingSince = now;
      _startAnchor = position;
      _startDistanceMeters = 0;
      _ensureConfirmSampling();
    } else if (_startAnchor != null) {
      _startDistanceMeters = Geolocator.distanceBetween(
        _startAnchor!.latitude,
        _startAnchor!.longitude,
        position.latitude,
        position.longitude,
      );
    }

    final elapsed = now.difference(_drivingSince!).inSeconds;
    final needSeconds = _startConfirmSeconds;
    final remaining = math.max(0, needSeconds - elapsed);
    final needDist = _minStartDistanceMeters;
    final distOk = _startDistanceMeters >= needDist;
    final timeOk = elapsed >= needSeconds;

    _setPhase(
      AutoDetectPhase.confirmingStart,
      detail:
          '${mpsToMph(speed).toStringAsFixed(0)} mph · '
          '${_startDistanceMeters.round()} m'
          '${timeOk ? '' : ' · ${remaining}s'}'
          '${distOk ? '' : ' · need ${needDist.round()} m'}',
    );

    if (timeOk && distOk && !_startInFlight) {
      _tripActive = true;
      _startInFlight = true;
      _tripStartedAt = now;
      _resetStartWindow();
      _resetActiveDistance();
      _activeAnchor = position;
      _setPhase(AutoDetectPhase.tripActive, detail: 'Starting GPS trip…');
      // Fire-and-forget; AppState owns async start.
      unawaited(onTripStarted());
    }
  }

  /// Call while a trip is active to auto-stop when the vehicle has been parked.
  /// [tripMiles] — live miles from TripTracker (helps maturity when path sparse).
  /// [walking] — Core Motion walking only (not still/unknown). Vehicle-gate on.
  void evaluateActiveTrip(
    Position position, {
    double tripMiles = 0,
    bool walking = false,
    DateTime? clock,
  }) {
    if (!_tripActive || _endInFlight) return;
    if (!_isUsableFix(position)) return;

    final speed = estimateSpeedMps(position, _lastPosition);
    _lastSpeedMps = speed;
    final now = clock ?? DateTime.now();
    _lastAcceptedFixAt = now;
    if (speed >= _mode.silenceGuardSpeedMps) {
      _lastHighSpeedAt = now;
    }

    // Accumulate path length for min-distance gate before auto-stop.
    if (_activeAnchor != null) {
      final step = Geolocator.distanceBetween(
        _activeAnchor!.latitude,
        _activeAnchor!.longitude,
        position.latitude,
        position.longitude,
      );
      if (step > 3 && step < 500) {
        _activeDistanceMeters += step;
        _activeAnchor = position;
      } else if (step >= 500) {
        _activeAnchor = position;
      }
    } else {
      _activeAnchor = position;
    }

    final mature = _isTripMature(now, tripMiles);

    // Above park speed — a crawl is still a trip. Only a real stop ends it.
    if (speed > _stopSpeedMps) {
      _lastMovingAt = now;
      _lastSampleLookedParked = false;
      _walkSince = null;
      if (_stoppedSince != null) {
        _resetStopWindow();
      }
      if (_pendingEndSince != null) {
        _cancelPendingEnd();
        _setPhase(
          AutoDetectPhase.tripActive,
          detail: '${mpsToMph(speed).toStringAsFixed(0)} mph · stitched',
        );
      } else {
        _setPhase(
          AutoDetectPhase.tripActive,
          detail: '${mpsToMph(speed).toStringAsFixed(0)} mph',
        );
      }
      _lastPosition = position;
      return;
    }

    // Strict parked / crawl sample (≤ ~3.4 mph).
    _lastSampleLookedParked = true;

    if (!mature) {
      _resetStopWindow();
      final tripAgeSec = _tripStartedAt == null
          ? 0
          : now.difference(_tripStartedAt!).inSeconds;
      final needSec = math.max(0, _mode.minActiveTripSeconds - tripAgeSec);
      final needM = math.max(
        0,
        (_mode.minActiveTripMeters - _activeDistanceMeters).round(),
      );
      _setPhase(
        AutoDetectPhase.tripActive,
        detail: needSec > 0
            ? 'Trip young · ${needSec}s before auto-end'
            : 'Need ${needM}m more before auto-end',
      );
      _lastPosition = position;
      return;
    }

    if (_stoppedSince == null) {
      _stoppedSince = now;
      _stopAnchor = position;
      _stopDistanceMeters = 0;
    } else if (_stopAnchor != null) {
      _stopDistanceMeters = Geolocator.distanceBetween(
        _stopAnchor!.latitude,
        _stopAnchor!.longitude,
        position.latitude,
        position.longitude,
      );
      if (_stopDistanceMeters >= stopCancelDistanceMeters) {
        _lastMovingAt = now;
        _lastSampleLookedParked = false;
        _walkSince = null;
        _resetStopWindow();
        _setPhase(
          AutoDetectPhase.tripActive,
          detail: 'Still moving (${_stopDistanceMeters.round()} m)',
        );
        _lastPosition = position;
        return;
      }
    }

    if (_tickPendingEnd(now)) {
      _lastPosition = position;
      return;
    }

    final elapsed = now.difference(_stoppedSince!).inSeconds;
    final need = _mode.stopConfirmSeconds;
    final remaining = math.max(0, need - elapsed);

    _setPhase(
      AutoDetectPhase.confirmingStop,
      detail: 'Parked ${elapsed}s · ends in ${remaining}s',
    );

    if (elapsed >= need) {
      _requestTripEnd('park', now);
      _lastPosition = position;
      return;
    }

    if (_tryWalkToEnd(
      walking: walking,
      parked: true,
      mature: true,
      now: now,
    )) {
      _lastPosition = position;
      return;
    }

    _lastPosition = position;
  }

  /// Wall-clock checks when GPS samples stop arriving.
  /// Strict park only if the last sample was stopped.
  /// Also ends mature trips after prolonged GPS silence (garage / canyon).
  /// [clock] is for tests; production callers omit it.
  bool tickParkWatchdog({
    double tripMiles = 0,
    DateTime? clock,
    bool walking = false,
  }) {
    if (!_tripActive || _endInFlight) return false;

    final now = clock ?? DateTime.now();
    if (_tickPendingEnd(now)) return true;
    if (!_isTripMature(now, tripMiles)) return false;

    // GPS silence failsafe: stream often dies when nearly still at destination.
    // Previously we refused to end unless the *last* sample looked parked —
    // a last moving fix + silence left long trips open forever (Build 16).
    final lastFix = _lastAcceptedFixAt ?? _lastMovingAt;
    if (lastFix != null) {
      final silenceSec = now.difference(lastFix).inSeconds;
      final soft = _mode.gpsSilenceFailsafeSeconds;
      final lastSlow = _lastSpeedMps == null ||
          _lastSpeedMps! <= _mode.stopSpeedMps ||
          _lastSampleLookedParked;
      final recentlyFast = _lastHighSpeedAt != null &&
          now.difference(_lastHighSpeedAt!) <
              Duration(seconds: _mode.gpsSilenceFailsafeSeconds + 60);
      // Cellular dropouts look like GPS silence while still rolling.
      // Only a parked-looking last sample may silence-end.
      if (lastSlow &&
          silenceSec >= absoluteGpsSilenceSeconds &&
          !recentlyFast) {
        _setPhase(
          AutoDetectPhase.confirmingStop,
          detail: 'GPS quiet ${silenceSec}s · ending…',
        );
        _requestTripEnd('absolute_silence', now);
        return true;
      }
      if (lastSlow && silenceSec >= soft && !recentlyFast) {
        _setPhase(
          AutoDetectPhase.confirmingStop,
          detail: 'GPS quiet ${silenceSec}s · ending…',
        );
        _requestTripEnd('silence', now);
        return _tickPendingEnd(now);
      }
      if (!lastSlow && silenceSec >= rollingSilenceGiveUpSeconds) {
        _setPhase(
          AutoDetectPhase.confirmingStop,
          detail: 'GPS quiet ${silenceSec}s · ending…',
        );
        _requestTripEnd('absolute_silence', now);
        return true;
      }
    }

    // Strict park watchdog: last sample was crawl/stopped.
    if (!_lastSampleLookedParked) return false;

    if (_tryWalkToEnd(
      walking: walking,
      parked: true,
      mature: true,
      now: now,
    )) {
      return true;
    }

    final parkedSince = _stoppedSince ?? _lastMovingAt;
    if (parkedSince == null) return false;

    final stillSec = now.difference(parkedSince).inSeconds;
    final need = _mode.stopConfirmSeconds;
    if (stillSec < need) {
      if (_phase == AutoDetectPhase.tripActive ||
          _phase == AutoDetectPhase.confirmingStop) {
        _setPhase(
          AutoDetectPhase.confirmingStop,
          detail: 'Parked ${stillSec}s · ends in ${need - stillSec}s',
        );
      }
      return false;
    }

    _requestTripEnd('park_watchdog', now);
    return _tickPendingEnd(now);
  }

  bool _isTripMature(DateTime now, double tripMiles) {
    final tripAgeSec = _tripStartedAt == null
        ? 0
        : now.difference(_tripStartedAt!).inSeconds;
    final minSec = _mode.minActiveTripSeconds;
    final minM = _mode.minAutoEndMeters;
    final pathOk = _activeDistanceMeters >= minM;
    final milesOk = tripMiles * 1609.34 >= minM;
    return tripAgeSec >= minSec && (pathOk || milesOk);
  }

  void _requestTripEnd(String reason, DateTime now) {
    if (_endInFlight || !_tripActive) return;
    // Garage / killed-stream recovery — do not wait to stitch.
    if (reason == 'absolute_silence') {
      _pendingEndReason = reason;
      _commitPendingEnd();
      return;
    }
    _pendingEndSince ??= now;
    _pendingEndReason ??= reason;
    final left = math.max(
      0,
      _stitchHold.inSeconds - now.difference(_pendingEndSince!).inSeconds,
    );
    _setPhase(
      AutoDetectPhase.confirmingStop,
      detail: left == 0
          ? 'Ending trip ($reason)…'
          : 'Holding ${left}s · stitch if you keep moving',
    );
  }

  bool _tickPendingEnd(DateTime now) {
    final started = _pendingEndSince;
    if (started == null || _endInFlight || !_tripActive) return false;
    if (now.difference(started) < _stitchHold) {
      final left =
          _stitchHold.inSeconds - now.difference(started).inSeconds;
      _setPhase(
        AutoDetectPhase.confirmingStop,
        detail: 'Holding ${math.max(0, left)}s · stitch if you keep moving',
      );
      return false;
    }
    _commitPendingEnd();
    return true;
  }

  void _cancelPendingEnd() {
    _pendingEndSince = null;
    _pendingEndReason = null;
  }

  void _commitPendingEnd() {
    if (_endInFlight || !_tripActive) return;
    _endInFlight = true;
    final reason = _pendingEndReason ?? 'park';
    _pendingEndSince = null;
    _pendingEndReason = null;
    _resetStopWindow();
    _setPhase(AutoDetectPhase.confirmingStop, detail: 'Ending trip ($reason)…');
    unawaited(onTripEnded());
  }

  bool _isUsableFix(Position position) {
    if (position.accuracy > maxAccuracyMeters) return false;
    if (position.latitude == 0 && position.longitude == 0) return false;
    return true;
  }

  void _resetStartWindow() {
    _drivingSince = null;
    _startAnchor = null;
    _startDistanceMeters = 0;
    _startSpeedDipSince = null;
    _endConfirmSampling();
  }

  /// Walking after a real park — not still, not unknown, not rolling in traffic.
  bool _tryWalkToEnd({
    required bool walking,
    required bool parked,
    required bool mature,
    required DateTime now,
  }) {
    // Still in the car — Core Motion often says walking at a light.
    if (carLinked) {
      _walkSince = null;
      return false;
    }
    if (!walking || !parked || !mature) {
      _walkSince = null;
      return false;
    }
    if (_stopDistanceMeters >= stopCancelDistanceMeters) {
      _walkSince = null;
      return false;
    }
    _walkSince ??= now;
    final elapsed = now.difference(_walkSince!).inSeconds;
    final need = walkToEndHold.inSeconds;
    final left = math.max(0, need - elapsed);
    _setPhase(
      AutoDetectPhase.confirmingStop,
      detail: left == 0
          ? 'Walking after park · ending…'
          : 'Walking after park ${elapsed}s · ends in ${left}s',
    );
    if (elapsed >= need) {
      _requestTripEnd('walk', now);
      return _tickPendingEnd(now);
    }
    return false;
  }

  void _resetStopWindow() {
    _stoppedSince = null;
    _stopAnchor = null;
    _stopDistanceMeters = 0;
    _walkSince = null;
  }

  void _resetActiveDistance() {
    _activeAnchor = null;
    _activeDistanceMeters = 0;
  }

  void _setPhase(AutoDetectPhase phase, {String? detail}) {
    final changed = _phase != phase || _statusDetail != detail;
    _phase = phase;
    _statusDetail = detail;
    if (changed) notifyListeners();
  }

  /// Prefer device speed; fall back to distance/time between samples.
  static double estimateSpeedMps(Position current, Position? previous) {
    final reported = current.speed;
    if (reported >= 0 && reported < 90) {
      // Some devices report 0 when moving slowly — blend with derived if available.
      if (reported > 0.5 || previous == null) return reported;
    }

    if (previous == null) return reported >= 0 ? reported : 0;

    final meters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    final dtMs = current.timestamp.difference(previous.timestamp).inMilliseconds;
    if (dtMs <= 0) return reported >= 0 ? reported : 0;
    final derived = meters / (dtMs / 1000.0);
    if (derived > 90) return reported >= 0 ? reported : 0; // teleport
    if (reported >= 0 && reported <= 0.5 && derived > reported) {
      return derived;
    }
    return reported >= 0 ? reported : derived;
  }

  static double mpsToMph(double mps) => mps * 2.23694;

  @override
  void dispose() {
    _subscription?.cancel();
    _idleSleepTimer?.cancel();
    _restart.dispose();
    super.dispose();
  }
}
