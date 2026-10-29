import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloud bridge for LicenseLogger phone app.
/// Off by default. Enable with `--dart-define=LL_CLOUD=true` plus URL/anon key defines.
/// When off, all methods no-op so SharedPreferences local mode keeps working.
class CloudSync {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  static const enabled = bool.fromEnvironment('LL_CLOUD', defaultValue: false);
  static const url = String.fromEnvironment('LL_SUPABASE_URL', defaultValue: '');
  static const anon = String.fromEnvironment('LL_SUPABASE_ANON', defaultValue: '');

  bool get isReady => enabled && url.isNotEmpty && anon.isNotEmpty && Supabase.instance.client.auth.currentSession != null;

  Future<void> init() async {
    if (!enabled) {
      debugPrint('CloudSync: local-only (LL_CLOUD not set)');
      return;
    }
    if (url.isEmpty || anon.isEmpty) {
      debugPrint('CloudSync: missing LL_SUPABASE_URL / LL_SUPABASE_ANON');
      return;
    }
    await Supabase.initialize(url: url, publishableKey: anon);
  }

  SupabaseClient? get client {
    if (!enabled || url.isEmpty) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<String?> signIn(String email, String password) async {
    final c = client;
    if (c == null) return 'Cloud sync is off';
    await c.auth.signInWithPassword(email: email, password: password);
    return null;
  }

  Future<void> signOut() async {
    await client?.auth.signOut();
  }

  /// Upload a finished practice drive payload (chunks optional). Soft-fails when offline/cloud off.
  Future<String?> uploadDrive({
    required String studentId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationMinutes,
    required int nightMinutes,
    required double distanceMiles,
    String kind = 'practice',
    String startLabel = '',
    String endLabel = '',
  }) async {
    final c = client;
    if (c == null || !isReady) return 'skipped';
    try {
      await c.from('drives').insert({
        'student_id': studentId,
        'kind': kind,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'night_minutes': nightMinutes,
        'distance_miles': distanceMiles,
        'start_label': startLabel,
        'end_label': endLabel,
        'status': 'pending',
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<Map<String, dynamic>?> ruleProgress(String studentId) async {
    final c = client;
    if (c == null || !isReady) return null;
    final raw = await c.rpc('student_rule_progress', params: {'p_student_id': studentId});
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }
}
