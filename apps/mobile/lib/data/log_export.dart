// Local-first adapter: AppState -> LogInput, plus CSV and share helpers.
// Only done practice drives are listed. Instruction is counted as excluded
// school lessons. Weather is 0 until the phone stores it. Permit number is
// blank (not in AppSettings).
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/lesson.dart';
import '../state/app_state.dart';
import 'log_layouts.dart';
import 'log_pdf.dart';

String isoDate(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

String hhmm(DateTime d) => '${pad2(d.hour)}:${pad2(d.minute)}';

LogInput logInputFromApp(AppState app) {
  final s = app.settings;
  final j = app.jurisdiction;
  final code = (j?.stateCode.isNotEmpty == true)
      ? j!.stateCode
      : (s.stateName.length == 2 ? s.stateName.toUpperCase() : s.stateName);
  final practice = <Lesson>[];
  var unsignedDrives = 0;
  var unsignedMinutes = 0;
  var lessons = 0;
  for (final l in app.lessons) {
    if (l.status != LessonStatus.done) continue;
    if (l.kind == DriveKind.instruction) {
      lessons++;
      continue;
    }
    practice.add(l);
  }
  final sum = app.hoursSummary;
  late final int total;
  late final int night;
  late final int day;
  late final int weather;
  if (sum != null) {
    total = sum.credited;
    night = sum.night;
    day = (total - night).clamp(0, total);
    weather = sum.weatherCredited;
  } else {
    total = practice.fold(0, (a, l) => a + (l.creditedSeconds / 60).round());
    night = practice.fold(0, (a, l) => a + (l.creditedNightSeconds / 60).round());
    day = (total - night).clamp(0, total);
    weather = 0;
  }
  return LogInput(
    stateCode: code,
    stateName: j?.stateName ?? s.stateName,
    student: LogStudent(
      first: s.firstName,
      last: s.lastName,
      permitNumber: '',
      birthday: s.birthday == null ? '' : isoDate(s.birthday!),
      permitIssued: s.permitIssued == null ? '' : isoDate(s.permitIssued!),
      school: '',
    ),
    mainSupervisor: '',
    drives: [
      for (final l in practice)
        LogDriveInput(
          date: isoDate(l.start),
          start: hhmm(l.start),
          end: hhmm(l.end ?? l.start.add(Duration(seconds: l.durationSeconds))),
          minutes: (l.creditedSeconds / 60).round(),
          nightMinutes: (l.creditedNightSeconds / 60).round(),
          weatherMinutes: 0,
          location: l.meet,
          notes: l.notes,
        ),
    ],
    totals: LogTotals(total: total, day: day, night: night, weather: weather),
    excluded: LogExcluded(
      unsignedDrives: unsignedDrives,
      unsignedMinutes: unsignedMinutes,
      lessons: lessons,
    ),
  );
}

String csvCell(Object? v) {
  var s = v == null ? '' : '$v';
  if (RegExp(r'^[=+\-@\t\r]').hasMatch(s)) s = "'$s";
  if (RegExp(r'["\n\r,]').hasMatch(s)) return '"${s.replaceAll('"', '""')}"';
  return s;
}

/// Spreadsheet of the signed practice drives listed on the log.
String renderLogCsv(LogInput input, LogDocument doc) {
  const header = [
    'date',
    'start',
    'end',
    'minutes',
    'night_minutes',
    'weather_minutes',
    'weather',
    'roadway',
    'supervisor',
    'initials',
    'skills',
    'conditions',
    'location',
    'notes',
  ];
  final rows = [
    header.map(csvCell).join(','),
    for (final d in [...input.drives]..sort((a, b) => (a.date + a.start).compareTo(b.date + b.start)))
      [
        d.date,
        d.start,
        d.end,
        d.minutes,
        d.nightMinutes,
        d.weatherMinutes,
        d.weather,
        d.roadway,
        d.supervisor,
        d.initials,
        d.skills.join('; '),
        d.conditions.join('; '),
        d.location,
        d.notes,
      ].map(csvCell).join(','),
  ];
  final meta = [
    csvCell('state'),
    csvCell(doc.stateCode),
    csvCell(doc.formLabel),
    csvCell(doc.title),
  ].join(',');
  return '\uFEFF$meta\r\n${rows.join('\r\n')}\r\n';
}

String _stamp() {
  final n = DateTime.now().toUtc();
  return '${n.year}-${pad2(n.month)}-${pad2(n.day)} ${pad2(n.hour)}:${pad2(n.minute)} UTC';
}

Future<void> shareLogPdf(LogDocument doc) async {
  final bytes = await renderStateLogPdf(
    doc,
    generatedAt: _stamp(),
    exportId: 'phone',
  );
  final dir = await getTemporaryDirectory();
  final name = 'LicenseLogger_${doc.stateCode}_log.pdf';
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf', name: name)],
      subject: '${doc.stateName} ${doc.formLabel} log'.trim(),
    ),
  );
}

Future<void> shareLogCsv(LogInput input, LogDocument doc) async {
  final csv = renderLogCsv(input, doc);
  final dir = await getTemporaryDirectory();
  final name = 'LicenseLogger_${doc.stateCode}_log.csv';
  final file = File('${dir.path}/$name');
  await file.writeAsString(csv, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv', name: name)],
      subject: '${doc.stateName} drive log CSV'.trim(),
    ),
  );
}
