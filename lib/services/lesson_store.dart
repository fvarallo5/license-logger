import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/lesson.dart';

class LessonStore {
  static const _lessonsKey = 'll.lessons';
  static const _settingsKey = 'll.settings';

  Future<List<Lesson>> loadLessons() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lessonsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.start.compareTo(a.start));
  }

  Future<void> saveLessons(List<Lesson> lessons) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lessonsKey,
      jsonEncode(lessons.map((l) => l.toJson()).toList()),
    );
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const AppSettings();
    return AppSettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
