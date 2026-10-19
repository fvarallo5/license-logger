import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battery_mode.dart';

class BatteryService extends ChangeNotifier {
  static const _key = 'll.battery_mode';

  /// Balanced is the everyday default (better start/stop than pure saver).
  BatteryMode mode = BatteryMode.balanced;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    mode = BatteryMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => BatteryMode.balanced,
    );
    notifyListeners();
  }

  Future<void> setMode(BatteryMode next) async {
    mode = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next.name);
    notifyListeners();
  }
}