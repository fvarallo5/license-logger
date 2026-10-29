import 'dart:async';
import 'dart:math' as math;

/// Backoff helper for restarting GPS / location streams after errors.
class StreamRestartScheduler {
  StreamRestartScheduler({this.maxAttempts = 8});

  final int maxAttempts;
  Timer? _timer;
  int attempts = 0;

  bool get exhausted => attempts >= maxAttempts;

  void reset() {
    attempts = 0;
    _timer?.cancel();
    _timer = null;
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Schedule [restart] after exponential-ish backoff. No-op if exhausted.
  void schedule(void Function() restart) {
    if (exhausted) return;
    _timer?.cancel();
    final delay = Duration(seconds: math.min(30, 2 + attempts * 3));
    attempts++;
    _timer = Timer(delay, restart);
  }

  void dispose() => cancel();
}
