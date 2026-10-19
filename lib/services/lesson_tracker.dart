import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'geo.dart';

class LiveFix {
  const LiveFix({required this.lat, required this.lng, required this.speedMps, required this.at});
  final double lat;
  final double lng;
  final double speedMps;
  final DateTime at;
}

/// GPS while a lesson is open, or while auto-track is watching for a drive.
class LessonTracker {
  StreamSubscription<Position>? _sub;
  LiveFix? last;
  double miles = 0;
  DateTime? movingSince;
  DateTime? stoppedSince;

  static const autoStartMph = 12.0;
  static const autoStopMph = 3.0;
  static const autoStartHold = Duration(seconds: 20);
  static const autoStopHold = Duration(minutes: 5);

  bool get isListening => _sub != null;

  Future<bool> ensurePermission({required bool background}) async {
    try {
      var enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return false;
      }
      if (background && perm == LocationPermission.whileInUse) {
        perm = await Geolocator.requestPermission();
      }
      return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  LocationSettings locationSettings({required bool background}) {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 8,
        intervalDuration: const Duration(seconds: 4),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'LicenseLogger',
          notificationText: background ? 'Auto-track is watching for a lesson' : 'Logging a lesson',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 8,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: background,
        allowBackgroundLocationUpdates: background,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 8);
  }

  Future<void> listen(void Function(LiveFix fix) onFix, {bool background = true}) async {
    if (isListening) return;
    try {
      _sub = Geolocator.getPositionStream(locationSettings: locationSettings(background: background)).listen((pos) {
        if (!pos.latitude.isFinite || !pos.longitude.isFinite) return;
        final fix = LiveFix(
          lat: pos.latitude,
          lng: pos.longitude,
          speedMps: pos.speed.isFinite ? pos.speed : 0,
          at: pos.timestamp,
        );
        if (last != null) {
          final d = Geo.miles(last!.lat, last!.lng, fix.lat, fix.lng);
          if (d > 0 && d < 2) miles += d;
        }
        last = fix;
        final mph = Geo.mphFromMps(fix.speedMps);
        if (mph >= autoStartMph) {
          movingSince ??= fix.at;
          stoppedSince = null;
        } else if (mph <= autoStopMph) {
          stoppedSince ??= fix.at;
          movingSince = null;
        }
        onFix(fix);
      });
    } catch (_) {
      _sub = null;
    }
  }

  bool get heldMoving {
    final from = movingSince;
    if (from == null) return false;
    return DateTime.now().difference(from) >= autoStartHold;
  }

  bool get heldStopped {
    final from = stoppedSince;
    if (from == null) return false;
    return DateTime.now().difference(from) >= autoStopHold;
  }

  void resetMotion() {
    movingSince = null;
    stoppedSince = null;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void resetMiles() {
    miles = 0;
    last = null;
  }
}
