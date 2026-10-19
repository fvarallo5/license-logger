import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/geo_point.dart';
import '../utils/stream_restart_scheduler.dart';
import 'adaptive_gps.dart';
import 'battery_mode.dart';

class TripTracker {
  static const _activeKey = 'll.tracking_active';
  static const _milesKey = 'll.tracking_miles';
  static const _backgroundKey = 'll.tracking_background';
  static const _autoKey = 'll.tracking_auto';

  /// Reject GPS fixes worse than this (meters) — cuts noise without more samples.
  static const maxAccuracyMeters = 45.0;

  /// Reject jumps that imply > ~120 mph (teleport / multipath glitches).
  static const maxSpeedMps = 53.0;

  /// Ignore samples older than this (stale cached fixes).
  /// Long enough to bridge a cellular GPS dropout without dropping the resume fix.
  static const maxFixAge = Duration(minutes: 3);

  /// Don't write SharedPreferences more often than this while driving.
  static const _persistMinInterval = Duration(seconds: 3);

  static const _startedAtKey = 'll.tracking_started_at';
  static const _pausedKey = 'll.tracking_paused';

  StreamSubscription<Position>? _subscription;
  final List<Position> _positions = [];
  double _miles = 0;
  bool _tracking = false;
  bool _background = false;
  bool _autoStarted = false;
  bool _paused = false;
  /// Tighter GPS while confirming a park so background auto-end still gets samples.
  bool _parkSampling = false;
  BatteryMode _batteryMode = BatteryMode.balanced;
  GpsSampleBand _sampleBand = GpsSampleBand.urban;
  double? _lastHeadingDeg;
  DateTime? _lastPersistAt;
  DateTime? _startedAt;
  /// Bumps on start/stop so in-flight SharedPreferences writes can't revive a stopped trip.
  int _sessionEpoch = 0;
  final _restart = StreamRestartScheduler();

  /// Latest horizontal accuracy (meters) for UI diagnostics; null if none yet.
  double? lastAccuracyMeters;

  /// Last stream error message, if any.
  String? lastStreamError;

  void Function(Position position)? onPosition;

  bool get isTracking => _tracking;
  bool get isPaused => _tracking && _paused;
  bool get isBackground => _background;
  bool get isAutoStarted => _autoStarted;
  double get currentMiles => _miles;
  int get positionCount => _positions.length;
  List<GeoPoint> get currentRoute => List.unmodifiable(
        _positions.map((p) => GeoPoint(p.latitude, p.longitude)),
      );
  BatteryMode get batteryMode => _batteryMode;
  DateTime? get startedAt => _startedAt;
  GpsSampleBand get sampleBand => _sampleBand;

  Future<String?> requestForegroundPermission() async {
    try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Please turn on Location Services';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Location permission denied';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission permanently denied. Enable in Settings.';
    }
    return null;
    } catch (e) {
      if (e.toString().contains('MissingPluginException')) return null;
      return 'Location is unavailable.';
    }
  }

  /// True when the user must open app Settings to grant Always / all-the-time.
  static bool isAlwaysSettingsRequired(String? message) {
    if (message == null) return false;
    final m = message.toLowerCase();
    return m.contains('always') ||
        m.contains('allow all the time') ||
        m.contains('background location');
  }

  /// Whether Always / Allow all the time is already granted (skip explainer).
  static Future<bool> hasAlwaysLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  Future<String?> requestBackgroundPermission() async {
    try {
    final foregroundError = await requestForegroundPermission();
    if (foregroundError != null) return foregroundError;

    if (Platform.isAndroid) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always) return null;
      return 'Background location is required for auto-track. Enable "Allow all the time" in Settings.';
    }

    if (Platform.isIOS) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Location permission is required for background tracking.';
      }
      if (permission != LocationPermission.always) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always) return null;
      if (permission == LocationPermission.whileInUse) {
        return 'Background tracking requires Always location. Enable it in Settings → LicenseLogger → Location → Always.';
      }
      return 'Location permission is required for background tracking.';
    }

    return null;
    } catch (e) {
      if (e.toString().contains('MissingPluginException')) return null;
      return 'Location is unavailable.';
    }
  }

  Future<void> restoreSession({
    BatteryMode batteryMode = BatteryMode.balanced,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_activeKey) ?? false)) return;

    _miles = prefs.getDouble(_milesKey) ?? 0;
    _background = prefs.getBool(_backgroundKey) ?? false;
    _autoStarted = prefs.getBool(_autoKey) ?? false;
    _paused = prefs.getBool(_pausedKey) ?? false;
    final startedRaw = prefs.getString(_startedAtKey);
    _startedAt = startedRaw != null ? DateTime.tryParse(startedRaw) : null;
    _startedAt ??= DateTime.now();
    _tracking = true;
    _batteryMode = batteryMode;
    _sampleBand = GpsSampleBand.urban;
    _lastHeadingDeg = null;
    await _beginStream(background: _background);
  }

  Future<void> start({
    bool background = false,
    bool autoStarted = false,
    BatteryMode batteryMode = BatteryMode.balanced,
  }) async {
    if (_tracking) return;

    _sessionEpoch += 1;
    final epoch = _sessionEpoch;
    _positions.clear();
    _miles = 0;
    _sampleBand = GpsSampleBand.urban;
    _lastHeadingDeg = null;
    _tracking = true;
    _background = background;
    _autoStarted = autoStarted;
    _paused = false;
    _batteryMode = batteryMode;
    _startedAt = DateTime.now();
    lastAccuracyMeters = null;
    lastStreamError = null;
    _lastPersistAt = null;
    _restart.reset();

    // Don't await getCurrentPosition on auto-start — in the background it
    // often hits the 8s timeLimit and delays (or drops) the next trip.
    if (!autoStarted) {
      await _seedFirstFix();
      if (!_tracking || epoch != _sessionEpoch) return;
    }
    await _beginStream(background: background);
    if (!_tracking || epoch != _sessionEpoch) return;
    await _persistSession(force: true);
  }

  /// Hot-swap GPS sampling while a trip is running (battery mode change).
  Future<void> applyBatteryMode(BatteryMode mode) async {
    _batteryMode = mode;
    if (!_tracking) return;
    await _beginStream(background: _background);
  }

  /// When parked, drop the distance filter so iOS keeps delivering fixes.
  /// Otherwise the stream goes silent, Dart timers die locked, and auto-end hangs.
  void setParkSampling(bool enabled) {
    if (!_tracking || _parkSampling == enabled) return;
    _parkSampling = enabled;
    unawaited(_beginStream(background: _background));
  }

  Future<void> _seedFirstFix() async {
    try {
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _batteryMode.activeLocationSettings.accuracy,
          timeLimit: const Duration(seconds: 8),
        ),
      );
      if (_tracking) _onPosition(fix);
    } catch (_) {
      // Stream will pick up; seed is best-effort.
    }
  }

  Future<void> _beginStream({required bool background}) async {
    await _subscription?.cancel();
    _restart.cancel();

    final settings = _buildSettings(background: background);
    try {
    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        lastStreamError = null;
        _restart.reset();
        _onPosition(position);
        onPosition?.call(position);
      },
      onError: (Object e) {
        lastStreamError = e.toString();
        _scheduleStreamRestart(background: background);
      },
      onDone: () {
        if (_tracking) {
          _scheduleStreamRestart(background: background);
        }
      },
      cancelOnError: false,
    );
    } catch (e) {
      lastStreamError = e.toString();
    }
  }

  void _scheduleStreamRestart({required bool background}) {
    if (!_tracking) return;
    _restart.schedule(() {
      if (_tracking) unawaited(_beginStream(background: background));
    });
  }

  LocationSettings _buildSettings({required bool background}) {
    final base = _batteryMode.activeLocationSettings;

    final filter = _activeDistanceFilter(base.distanceFilter);
    final accuracy =
        _parkSampling ? LocationAccuracy.medium : base.accuracy;
    final interval = _activeIntervalSeconds();

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: filter,
        intervalDuration: Duration(seconds: interval),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'LicenseLogger',
          notificationText: background
              ? 'Logging a lesson · ${_batteryMode.label}'
              : 'GPS active · ${_batteryMode.label}',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: accuracy,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: filter,
        // Keep active trips awake in traffic; idle watch pauses separately.
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: background,
        // Keep updates alive while a trip is active (screen locked / other apps).
        allowBackgroundLocationUpdates: background,
      );
    }

    return base;
  }

  int _activeDistanceFilter(int urbanFilter) {
    if (_parkSampling) return AdaptiveGps.parkDistanceFilter;
    if (_sampleBand == GpsSampleBand.highway &&
        _batteryMode.usesAdaptiveSampling) {
      return AdaptiveGps.highwayDistanceFilter;
    }
    return urbanFilter;
  }

  int _activeIntervalSeconds() {
    if (_parkSampling) return AdaptiveGps.parkIntervalSeconds;
    if (_sampleBand == GpsSampleBand.highway &&
        _batteryMode.usesAdaptiveSampling) {
      return AdaptiveGps.highwayIntervalSeconds;
    }
    return _batteryMode.activeIntervalSeconds;
  }

  void pause() {
    if (!_tracking || _paused) return;
    _paused = true;
    unawaited(_persistSession(force: true));
  }

  void resume() {
    if (!_tracking || !_paused) return;
    _paused = false;
    // New anchor so the pause gap isn't counted as miles.
    if (_positions.isNotEmpty) {
      final last = _positions.last;
      _positions
        ..clear()
        ..add(last);
    }
    unawaited(_persistSession(force: true));
  }

  void _onPosition(Position position) {
    if (!_tracking) return;
    if (_paused) {
      lastAccuracyMeters = position.accuracy;
      return;
    }

    if (!isUsableTripFix(position)) return;

    lastAccuracyMeters = position.accuracy;

    if (_positions.isNotEmpty) {
      final last = _positions.last;
      final meters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      final dtMs =
          position.timestamp.difference(last.timestamp).inMilliseconds;

      if (!shouldAcceptSegment(
        meters: meters,
        dtMs: dtMs,
        distanceFilter: _batteryMode.activeLocationSettings.distanceFilter,
        currentSpeedMps: position.speed,
      )) {
        return;
      }

      _miles += meters / 1609.34;
      unawaited(_persistSession());
    }
    _positions.add(position);
    _maybeAdaptSampling(position);
  }

  void _maybeAdaptSampling(Position position) {
    if (!_batteryMode.usesAdaptiveSampling) return;
    final heading = _headingDeg(position);
    final delta = heading == null || _lastHeadingDeg == null
        ? 999.0
        : AdaptiveGps.headingDeltaDeg(_lastHeadingDeg!, heading);
    if (heading != null) _lastHeadingDeg = heading;

    final next = AdaptiveGps.band(
      parkSampling: _parkSampling,
      mature: _tripIsMature,
      speedMps: position.speed,
      headingDeltaDeg: delta,
      current: _sampleBand,
    );
    if (next == _sampleBand) return;
    _sampleBand = next;
    unawaited(_beginStream(background: _background));
  }

  bool get _tripIsMature {
    final start = _startedAt;
    if (start == null) return false;
    if (DateTime.now().difference(start).inSeconds <
        _batteryMode.minActiveTripSeconds) {
      return false;
    }
    return _miles * 1609.34 >= _batteryMode.minActiveTripMeters;
  }

  double? _headingDeg(Position position) {
    if (position.headingAccuracy >= 0 &&
        position.headingAccuracy < 45 &&
        position.heading >= 0) {
      return position.heading;
    }
    if (_positions.length < 2) return null;
    final prev = _positions[_positions.length - 2];
    return Geolocator.bearingBetween(
      prev.latitude,
      prev.longitude,
      position.latitude,
      position.longitude,
    );
  }

  /// Shared filter for unit tests and live tracking.
  static bool isUsableTripFix(Position position) {
    if (position.accuracy > maxAccuracyMeters) return false;
    if (position.latitude == 0 && position.longitude == 0) return false;
    if (position.isMocked) return false;

    final age = DateTime.now().difference(position.timestamp);
    // Allow slightly future clocks; reject clearly stale samples.
    if (age > maxFixAge) return false;
    if (age < const Duration(seconds: -5)) return false;

    return true;
  }

  /// Segment acceptance: teleport, jitter, and stationary multipath.
  static bool shouldAcceptSegment({
    required double meters,
    required int dtMs,
    required int distanceFilter,
    double currentSpeedMps = -1,
  }) {
    if (dtMs > 0) {
      final speed = meters / (dtMs / 1000.0);
      if (speed > maxSpeedMps && meters > 80) return false;
      // Cellular / tunnel gap: keep the chord if implied speed is still driving.
      if (dtMs >= 20000 && meters >= 40 && speed >= 4.0 && speed <= maxSpeedMps) {
        return true;
      }
    } else if (meters > 200) {
      return false;
    }

    // Tiny jitter below a fraction of the distance filter is noise.
    final minStep = distanceFilter * 0.35;
    if (meters < minStep && meters < 8) return false;

    // Stationary multipath: device says stopped but coords wander a few meters.
    if (currentSpeedMps >= 0 && currentSpeedMps < 0.8 && meters < 12) {
      return false;
    }

    return true;
  }

  /// Stops tracking and returns miles + sparse route for map / cloud.
  ///
  /// Awaits clearing the persisted session so a kill/relaunch cannot revive
  /// the trip after stop (in-flight GPS persists are invalidated via epoch).
  Future<TripTrackResult> stop() async {
    final epoch = _sessionEpoch;
    _sessionEpoch += 1;
    _tracking = false;
    _background = false;
    _autoStarted = false;
    _paused = false;
    _parkSampling = false;
    _sampleBand = GpsSampleBand.urban;
    _lastHeadingDeg = null;
    await _subscription?.cancel();
    _subscription = null;
    _restart.cancel();

    final route = _positions
        .map((p) => GeoPoint(p.latitude, p.longitude))
        .toList(growable: false);
    final endedAt = DateTime.now();
    final result = TripTrackResult(
      miles: _miles,
      route: route,
      startedAt: _startedAt ?? endedAt,
      endedAt: endedAt,
    );

    _positions.clear();
    _miles = 0;
    _startedAt = null;
    lastAccuracyMeters = null;
    await _clearSession();
    // If a stale persist raced us, clear again (epoch already advanced).
    if (epoch + 1 == _sessionEpoch) {
      await _clearSession();
    }
    return result;
  }

  Future<void> _persistSession({bool force = false}) async {
    if (!_tracking) return;
    final epoch = _sessionEpoch;
    final miles = _miles;
    final background = _background;
    final autoStarted = _autoStarted;
    final paused = _paused;
    final startedAt = _startedAt;
    final now = DateTime.now();
    if (!force &&
        _lastPersistAt != null &&
        now.difference(_lastPersistAt!) < _persistMinInterval) {
      return;
    }
    _lastPersistAt = now;
    final prefs = await SharedPreferences.getInstance();
    // Drop write if trip stopped (or restarted) while we awaited prefs.
    if (!_tracking || epoch != _sessionEpoch) return;
    await prefs.setBool(_activeKey, true);
    await prefs.setDouble(_milesKey, miles);
    await prefs.setBool(_backgroundKey, background);
    await prefs.setBool(_autoKey, autoStarted);
    await prefs.setBool(_pausedKey, paused);
    if (startedAt != null) {
      await prefs.setString(_startedAtKey, startedAt.toIso8601String());
    }
    if (!_tracking || epoch != _sessionEpoch) {
      await _clearSession();
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    await prefs.remove(_milesKey);
    await prefs.remove(_backgroundKey);
    await prefs.remove(_autoKey);
    await prefs.remove(_pausedKey);
    await prefs.remove(_startedAtKey);
  }

  void dispose() {
    _subscription?.cancel();
    _restart.dispose();
  }
}
