import 'package:intl/intl.dart';

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _wdLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime d) => '${_wd[d.weekday - 1]}, ${_mo[d.month - 1]} ${d.day}';
String fmtDateLong(DateTime d) => '${_mo[d.month - 1]} ${d.day}, ${d.year}';
String fmtWeekday(DateTime d) => _wdLong[d.weekday - 1];
String fmtWd(DateTime d) => _wd[d.weekday - 1];
String fmtMonth(DateTime d) => _mo[d.month - 1];

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String formatMinutesHm(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String formatHours(double hours) {
  if (hours <= 0) return '0.0 h';
  return '${hours.toStringAsFixed(1)} h';
}

String formatMiles(double miles) {
  if (miles <= 0) return '0.0 mi';
  return '${miles.toStringAsFixed(1)} mi';
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}

String formatLessonWhen(DateTime start, DateTime? end) {
  final day = DateFormat.MMMd().format(start);
  final t = DateFormat.jm();
  if (end == null) return '$day · ${t.format(start)}';
  return '$day · ${t.format(start)}–${t.format(end)}';
}
