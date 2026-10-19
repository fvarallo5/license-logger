import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debounce leaving a vehicle so Core Motion flicker doesn't kill GPS watch.
class VehicleGateLatch {
  /// Keep GPS watching this long after the last automotive/cycling sample.
  Duration hold;

  VehicleGateLatch({this.hold = const Duration(seconds: 45)});

  bool latched = false;
  DateTime? leftAt;

  bool apply({required bool rawInVehicle, required DateTime now}) {
    if (rawInVehicle) {
      leftAt = null;
      latched = true;
      return latched;
    }
    if (!latched) return false;
    leftAt ??= now;
    if (now.difference(leftAt!) >= hold) {
      latched = false;
      leftAt = null;
    }
    return latched;
  }
}

/// Optional gate: only run auto-detect GPS watching when the OS reports
/// vehicle-like motion (in vehicle / bicycle).
class ActivityRecognitionService extends ChangeNotifier {
  static const _gateKey = 'll.activity_recognition_gate_enabled';
  static const _method = MethodChannel('com.ultraforge.licenselogger/motion');
  static const _events = EventChannel('com.ultraforge.licenselogger/motion_events');

  bool gateEnabled = false;
  bool available = true;
  bool inVehicle = false;
  bool hasPermission = false;
  String activity = 'unknown';
  int confidence = 0;
  final latch = VehicleGateLatch();

  StreamSubscription? _sub;
  bool _started = false;

  /// True when auto-detect may watch GPS (gate off, or currently in a vehicle).
  bool get allowsAutoDetectWatch => !gateEnabled || inVehicle;

  /// On-foot with a usable Core Motion sample — stop idle GPS even if locked.
  bool get isConfidentOnFoot {
    if (confidence < 50) return false;
    return activity == 'walking' ||
        activity == 'running' ||
        activity == 'on_foot';
  }

  void setExitHold(Duration hold) {
    latch.hold = hold;
  }

  String get activityLabel {
    return switch (activity) {
      'in_vehicle' => 'In vehicle',
      'on_bicycle' => 'Cycling',
      'on_foot' || 'walking' => 'Walking',
      'running' => 'Running',
      'still' => 'Still',
      'tilting' => 'Device moving',
      'unavailable' => 'Unavailable',
      _ => 'Unknown',
    };
  }

  String get statusLabel {
    if (!gateEnabled) return 'Gate off — always watch when auto-detect is on';
    if (!hasPermission) return 'Motion / activity permission needed';
    if (!available) return 'Activity recognition not available';
    if (inVehicle && latch.leftAt != null) {
      return 'Holding vehicle — GPS still watching ($activityLabel)';
    }
    if (inVehicle) return '$activityLabel — GPS can watch';
    return 'Waiting for vehicle motion… ($activityLabel)';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (Platform.isAndroid) {
      // Force-off if a previous build enabled the gate.
      gateEnabled = false;
      available = false;
      hasPermission = false;
      await prefs.setBool(_gateKey, false);
      notifyListeners();
      return;
    }
    // On by default on iPhone. Desktop/tests stay GPS-only until a real iOS
    // Motion sample exists.
    gateEnabled = prefs.getBool(_gateKey) ?? Platform.isIOS;
    if (gateEnabled) {
      await start();
    } else {
      await _refreshOnce();
    }
    notifyListeners();
  }

  Future<void> setGateEnabled(bool enabled) async {
    if (enabled && Platform.isAndroid) {
      // Not offered on Android (Play policy). Keep gate off.
      gateEnabled = false;
      available = false;
      hasPermission = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_gateKey, false);
      notifyListeners();
      return;
    }
    if (enabled) {
      final ok = await ensurePermission();
      if (!ok) {
        gateEnabled = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_gateKey, false);
        notifyListeners();
        return;
      }
    }

    gateEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gateKey, enabled);

    if (enabled) {
      await start();
      try {
        await _method.invokeMethod<void>('start');
      } catch (_) {}
    } else {
      try {
        await _method.invokeMethod<void>('stop');
      } catch (_) {}
      await stop();
      await _refreshOnce();
    }
    notifyListeners();
  }

  Future<bool> ensurePermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      // Play Health Apps policy: do not use ACTIVITY_RECOGNITION.
      hasPermission = false;
      available = false;
      notifyListeners();
      return false;
    }
    return requestSystemPrompt();
  }

  /// Shows the iOS Motion & Fitness system alert when status is notDetermined.
  Future<bool> requestSystemPrompt() async {
    if (kIsWeb || !Platform.isIOS) return false;
    try {
      final raw = await _method.invokeMethod<dynamic>('requestPermission');
      if (raw is Map) {
        _applyMap(Map<Object?, Object?>.from(raw));
      } else {
        await _refreshOnce();
      }
    } on MissingPluginException {
      available = false;
      hasPermission = false;
    } catch (_) {
      await _refreshOnce();
    }
    notifyListeners();
    return hasPermission;
  }

  Future<void> start() async {
    if (kIsWeb || _started) {
      await _refreshOnce();
      return;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      available = false;
      notifyListeners();
      return;
    }

    _started = true;
    try {
      _sub = _events.receiveBroadcastStream().listen(
        _onEvent,
        onError: (_) {
          available = false;
          notifyListeners();
        },
      );
      await _refreshOnce();
    } on MissingPluginException {
      available = false;
      _started = false;
      notifyListeners();
    } catch (_) {
      available = false;
      _started = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> refreshPermission() => _refreshOnce();

  Future<void> _refreshOnce() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      available = false;
      return;
    }
    try {
      final raw = await _method.invokeMethod<dynamic>('getState');
      if (raw is Map) {
        _applyMap(Map<Object?, Object?>.from(raw));
      }
    } on MissingPluginException {
      available = false;
    } catch (_) {}
  }

  void _onEvent(dynamic event) {
    if (event is Map) {
      final watchBefore = allowsAutoDetectWatch;
      _applyMap(Map<Object?, Object?>.from(event));
      // Always refresh the activity chip; GPS sync is cheap/idempotent.
      notifyListeners();
      if (kDebugMode && watchBefore != allowsAutoDetectWatch) {
        debugPrint(
          'VehicleGate watch=$allowsAutoDetectWatch activity=$activity '
          'rawHold=${latch.leftAt != null}',
        );
      }
    }
  }

  void _applyMap(Map<Object?, Object?> map) {
    available = map['available'] as bool? ?? true;
    hasPermission = map['permission'] as bool? ?? true;
    activity = map['activity'] as String? ?? 'unknown';
    final c = map['confidence'];
    confidence = c is int ? c : (c is num ? c.toInt() : 0);
    final raw = map['inVehicle'] as bool? ?? false;
    inVehicle = latch.apply(rawInVehicle: raw, now: DateTime.now());
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
