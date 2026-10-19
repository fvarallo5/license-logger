import 'package:intl/intl.dart';

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
