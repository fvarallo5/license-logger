import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cheap background wake while the high-accuracy GPS stream is off.
///
/// iOS: significant-change (cell / Wi-Fi). Android: network location with a
/// large displacement. Car-link and Core Motion stay on their own channels.
class IdleWakeService {
  static const _method = MethodChannel('com.ultraforge.licenselogger/idle_wake');
  static const _events = EventChannel('com.ultraforge.licenselogger/idle_wake_events');

  void Function(String reason)? onWake;

  StreamSubscription? _sub;
  bool running = false;

  Future<bool> start() async {
    if (kIsWeb) return false;
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    try {
      _sub ??= _events.receiveBroadcastStream().listen(_onEvent);
      final ok = await _method.invokeMethod<bool>('start');
      running = ok == true;
      return running;
    } on MissingPluginException {
      running = false;
      return false;
    } catch (_) {
      running = false;
      return false;
    }
  }

  Future<void> stop() async {
    running = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _method.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Tests / desktop.
    } catch (_) {}
  }

  void _onEvent(dynamic event) {
    if (event is Map) {
      final reason = event['reason'] as String? ?? 'significant_change';
      onWake?.call(reason);
    }
  }
}
