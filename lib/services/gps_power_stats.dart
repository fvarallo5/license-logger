/// Field counters for idle vs in-trip GPS radio time.
///
/// iOS Settings → Battery is a 24h blob; this is how we compare build 40
/// (~4–5%/hr) to the native-sleep path.
class GpsPowerStats {
  DateTime? _streamOnSince;
  DateTime? _asleepSince;
  Duration _streamOn = Duration.zero;
  Duration _asleep = Duration.zero;

  int samples = 0;
  int sleeps = 0;
  int wakes = 0;
  String lastWakeReason = 'app';
  String state = 'off';

  Duration get streamOn {
    final since = _streamOnSince;
    if (since == null) return _streamOn;
    return _streamOn + DateTime.now().difference(since);
  }

  Duration get asleep {
    final since = _asleepSince;
    if (since == null) return _asleep;
    return _asleep + DateTime.now().difference(since);
  }

  void markStreamOn() {
    _flushAsleep();
    _streamOnSince ??= DateTime.now();
    state = 'gps';
  }

  void markAsleep() {
    _flushStream();
    if (_asleepSince == null) {
      _asleepSince = DateTime.now();
      sleeps++;
    }
    state = 'sleep';
  }

  void markOff() {
    _flushStream();
    _flushAsleep();
    state = 'off';
  }

  void markSample() => samples++;

  void markWake(String reason) {
    wakes++;
    lastWakeReason = reason;
  }

  void reset() {
    _streamOnSince = null;
    _asleepSince = null;
    _streamOn = Duration.zero;
    _asleep = Duration.zero;
    samples = 0;
    sleeps = 0;
    wakes = 0;
    lastWakeReason = 'app';
    state = 'off';
  }

  String get summaryLine {
    final onMin = streamOn.inSeconds / 60.0;
    final offMin = asleep.inSeconds / 60.0;
    return 'GPS ${onMin.toStringAsFixed(1)} min on · '
        '${offMin.toStringAsFixed(1)} min sleep · '
        'woke $lastWakeReason';
  }

  void _flushStream() {
    final since = _streamOnSince;
    if (since == null) return;
    _streamOn += DateTime.now().difference(since);
    _streamOnSince = null;
  }

  void _flushAsleep() {
    final since = _asleepSince;
    if (since == null) return;
    _asleep += DateTime.now().difference(since);
    _asleepSince = null;
  }
}
