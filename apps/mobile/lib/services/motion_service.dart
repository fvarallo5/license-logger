import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hold GPS watch briefly after Core Motion leaves automotive (a light).
class VehicleLatch {
  VehicleLatch({this.hold = const Duration(seconds: 45)});

  Duration hold;
  bool latched = false;
  DateTime? leftAt;

  bool apply({required bool rawInVehicle, required DateTime now}) {
    if (rawInVehicle) {
      leftAt = null;
      latched = true;
      return true;
    }
    if (!latched) return false;
    leftAt ??= now;
    if (now.difference(leftAt!) >= hold) {
      latched = false;
      leftAt = null;
      return false;
    }
    return true;
  }

  void reset() {
    latched = false;
    leftAt = null;
  }
}

/// iOS Motion & Fitness (Core Motion). Android stays GPS-only (Play health policy).
class MotionService extends ChangeNotifier {
  MotionService({this.useNative = true});

  static const _method = MethodChannel('com.ultraforge.licenselogger/motion');
  static const _events = EventChannel('com.ultraforge.licenselogger/motion_events');

  final bool useNative;
  final latch = VehicleLatch();

  bool available = false;
  bool hasPermission = false;
  bool inVehicle = false;
  String activity = 'unknown';
  int confidence = 0;

  StreamSubscription<dynamic>? _sub;

  bool get iOS => !kIsWeb && Platform.isIOS;

  String get activityLabel {
    return switch (activity) {
      'in_vehicle' => 'In vehicle',
      'on_bicycle' => 'Cycling',
      'walking' => 'Walking',
      'running' => 'Running',
      'still' => 'Still',
      'unavailable' => 'Unavailable',
      _ => 'Unknown',
    };
  }

  String get permissionLabel {
    if (!iOS) return 'GPS speed only on this device';
    if (!available) return 'Motion isn’t available (Simulator has none)';
    if (hasPermission) return 'Allowed';
    return 'Off — tap to allow';
  }

  Future<void> applyNative(Map<dynamic, dynamic> raw) async {
    available = raw['available'] == true;
    hasPermission = raw['permission'] == true;
    activity = raw['activity'] as String? ?? 'unknown';
    confidence = (raw['confidence'] as num?)?.toInt() ?? 0;
    final vehicle = raw['inVehicle'] == true;
    inVehicle = latch.apply(rawInVehicle: vehicle, now: DateTime.now());
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    if (!useNative || !iOS) {
      available = false;
      hasPermission = false;
      notifyListeners();
      return false;
    }
    try {
      final raw = await _method.invokeMethod<dynamic>('requestPermission');
      if (raw is Map) await applyNative(raw);
      return hasPermission;
    } catch (_) {
      available = false;
      hasPermission = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> start() async {
    if (!useNative || !iOS) {
      available = false;
      notifyListeners();
      return;
    }
    try {
      final avail = await _method.invokeMethod<dynamic>('isAvailable');
      available = avail == true;
      await _sub?.cancel();
      _sub = _events.receiveBroadcastStream().listen((event) {
        if (event is Map) unawaited(applyNative(event));
      });
      final raw = await _method.invokeMethod<dynamic>('start');
      if (raw is Map) await applyNative(raw);
    } catch (_) {
      available = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (useNative && iOS) {
      try {
        await _method.invokeMethod<void>('stop');
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
