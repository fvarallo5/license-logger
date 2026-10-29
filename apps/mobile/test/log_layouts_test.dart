import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/data/log_export.dart';
import 'package:license_logger/data/log_layouts.dart';
import 'package:license_logger/data/log_pdf.dart';
import 'package:license_logger/data/state_rules.dart';
import 'package:license_logger/models/lesson.dart';
import 'package:license_logger/state/app_state.dart';

import 'helpers.dart';

/// flutter test runs from apps/mobile; docs live at the monorepo root.
String docsLayoutsDir() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = Directory('${dir.path}/docs/log_layouts');
    if (File('${candidate.path}/layouts.json').existsSync()) {
      return candidate.path;
    }
    dir = dir.parent;
  }
  throw StateError('docs/log_layouts not found from ${Directory.current.path}');
}

Layouts loadLayouts() =>
    Layouts.fromJsonString(File('assets/data/log_layouts.json').readAsStringSync());

LogInput fixtureInput(String state, {String? stateName}) {
  final j = jsonDecode(File('${docsLayoutsDir()}/fixtures/input.json').readAsStringSync()) as Map<String, dynamic>;
  j.remove('_doc');
  j['state_code'] = state;
  if (stateName != null) j['state_name'] = stateName;
  return LogInput.fromJson(j);
}

bool _same(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !_same(e.value, b[e.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_same(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}

String? firstDiff(Object? a, Object? b, [String path = r'$']) {
  if (_same(a, b)) return null;
  if (a is Map && b is Map) {
    final keys = {...a.keys, ...b.keys};
    for (final k in keys) {
      if (!a.containsKey(k)) return '$path.$k missing on left';
      if (!b.containsKey(k)) return '$path.$k missing on right';
      final d = firstDiff(a[k], b[k], '$path.$k');
      if (d != null) return d;
    }
  }
  if (a is List && b is List) {
    if (a.length != b.length) return '$path length ${a.length} vs ${b.length}';
    for (var i = 0; i < a.length; i++) {
      final d = firstDiff(a[i], b[i], '$path[$i]');
      if (d != null) return d;
    }
  }
  return '$path: $a vs $b';
}

void main() {
  late Layouts layouts;

  setUpAll(() {
    layouts = loadLayouts();
  });

  test('bundled log_layouts.json matches docs/log_layouts/layouts.json', () {
    expect(
      File('assets/data/log_layouts.json').readAsStringSync(),
      File('${docsLayoutsDir()}/layouts.json').readAsStringSync(),
    );
    expect(layouts.states.length, 39);
  });

  test('builder matches every shared fixture', () {
    final dir = Directory('${docsLayoutsDir()}/fixtures/expected');
    var n = 0;
    for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      final st = f.uri.pathSegments.last.substring(0, 2);
      final want = jsonDecode(f.readAsStringSync());
      final got = buildLogDocument(
        layouts,
        fixtureInput(st, stateName: st == 'ZZ' ? 'Nowhere' : null),
      ).toJson();
      final d = firstDiff(got, want);
      expect(d, isNull, reason: '$st $d');
      n++;
    }
    expect(n, 52);
  });

  test('formatting rules', () {
    expect(fmtAmount(90, 'hr_min'), '1 hr 30 min');
    expect(fmtAmount(60, 'hr_min'), '1 hr');
    expect(fmtAmount(45, 'hr_min'), '45 min');
    expect(fmtAmount(3000, 'minutes'), '3000');
    expect(fmtAmount(70, 'hm'), '1:10');
    expect(fmtHours(70), '1.17');
    expect(fmtHours(90), '1.5');
    expect(fmtHours(120), '2');
    expect(time12(0), '12:00 AM');
    expect(time12(19 * 60 + 10), '7:10 PM');
  });

  test('CA: official columns, skills abbreviated, 10 then 21 rows', () {
    final many = [
      for (var i = 0; i < 25; i++)
        LogDriveInput.fromJson({
          ...{
            'date': '2026-08-${(i + 1).toString().padLeft(2, '0')}',
            'start': '17:40',
            'end': '19:25',
            'minutes': 105,
            'night_minutes': 35,
            'weather_minutes': 105,
            'weather': 'Light rain',
            'roadway': 'Wet',
            'supervisor': 'Carlos Lopez',
            'initials': 'CL',
            'skills': ['Highway merge', 'Lane changes', 'Following distance'],
            'conditions': ['Wet', 'Light rain'],
            'location': 'Mueller to Round Rock',
            'notes': '',
          },
        }),
    ];
    final d = buildLogDocument(layouts, fixtureInput('CA').copyWithDrives(many));
    final t1 = d.pages[0].blocks.whereType<TableBlock>().first.table;
    expect(t1.panels[0].columns.map((c) => c.label).toList(), [
      'Date',
      'Driving Skills Practiced',
      'DAY',
      'NIGHT',
      'Skills needing more practice (use abbrev.)',
      'Adult’s Initials',
    ]);
    expect(t1.rowCount, 10);
    expect(t1.panels[0].rows[0], ['8/1/26', 'FD, LC, KSAC', '1 hr 10 min', '35 min', '', 'CL']);
    expect(t1.total!.label, 'TOTAL PRACTICE TIME');
    expect(d.pages.length, 2);
    expect((d.pages[1].blocks[0] as TableBlock).table.rowCount, 21);
    expect(d.disclaimerMode, 'check');
    expect(d.disclaimer, contains('check your state accepts this copy'));
  });

  test('NV: day/night split, transfer wording, certification first', () {
    final d = buildLogDocument(layouts, fixtureInput('NV'));
    expect(d.disclaimerMode, 'transfer');
    expect(d.disclaimer, contains('Filled copy to transfer/print onto the official Nevada DLD130'));
    expect(d.pages[0].blocks.whereType<SignaturesBlock>(), isNotEmpty);
    final t = d.pages[1].blocks[0] as TableBlock;
    final a = t.table.panels[0];
    final b = t.table.panels[1];
    expect(a.rows.any((r) => r.join('|') == '10/12/26|5:40 PM|6:50 PM|70'), isTrue);
    expect(b.rows.any((r) => r.join('|') == '10/12/26|6:50 PM|7:25 PM|35'), isTrue);
    expect(b.rows.any((r) => r.join('|') == '10/12/26|6:15 AM|6:35 AM|20'), isTrue);
    expect(t.table.total!.cells, [
      ['', '', '', '235'],
      ['', '', '', '115'],
    ]);
  });

  test('OH: hours/minutes split, notary on the affidavit page', () {
    final d = buildLogDocument(layouts, fixtureInput('OH'));
    expect(d.pages[0].blocks.whereType<NotaryBlock>(), isNotEmpty);
    final t = d.pages[1].blocks[0] as TableBlock;
    final row = t.table.panels[0].rows.firstWhere((r) => r[0] == '10/12/26' && r[3] == '5:40 PM');
    expect(row.sublist(5), ['1', '10', '0', '35']);
    expect(row[2], '');
  });

  test('MI accepted; FL / NY / NJ certification-only with supporting record', () {
    final mi = buildLogDocument(layouts, fixtureInput('MI'));
    expect(mi.disclaimerMode, 'accepted');
    expect(mi.disclaimer, contains('Other driving log formats will be accepted.'));
    for (final st in ['FL', 'NY', 'NJ']) {
      final d = buildLogDocument(layouts, fixtureInput(st));
      expect(d.kind, 'certification');
      expect(d.pages.length, greaterThanOrEqualTo(2));
      expect(jsonEncode(d.pages[1].toJson()), contains('not part of the official form'));
    }
    final fl = buildLogDocument(layouts, fixtureInput('FL'));
    expect(
      jsonEncode(fl.pages[0].toJson()),
      contains('I do hereby certify that Maya Lopez, a minor, date of birth 3/9/10'),
    );
    expect(fl.pages[0].blocks.whereType<NotaryBlock>(), isNotEmpty);
  });

  test('generic states say why', () {
    expect(buildLogDocument(layouts, fixtureInput('IL')).disclaimer, contains('could not be downloaded'));
    expect(buildLogDocument(layouts, fixtureInput('NM')).disclaimerMode, 'generic_accepted');
    expect(buildLogDocument(layouts, fixtureInput('GA')).disclaimerMode, 'generic_no_form');
    expect(buildLogDocument(layouts, fixtureInput('HI')).disclaimerMode, 'generic_unconfirmed');
  });

  test('banner titles', () {
    expect(bannerTitleFor('accepted'), 'Official layout · other formats accepted');
    expect(bannerTitleFor('transfer'), 'Copy onto the official form');
    expect(bannerTitleFor('check'), 'Official layout · check acceptance');
    expect(bannerTitleFor('generic_no_form'), 'Generic layout · check with your office');
  });

  test('PDFs render for several layouts', () async {
    for (final st in ['CA', 'OH', 'MI', 'NV', 'FL', 'NY', 'ME', 'MD', 'UT', 'KY', 'AZ', 'NM']) {
      final doc = buildLogDocument(layouts, fixtureInput(st));
      final bytes = await renderStateLogPdf(doc, generatedAt: 'now', exportId: 't');
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: st);
      expect(bytes.length, greaterThan(1500), reason: st);
    }
  });

  test('logInputFromApp lists done practice only', () async {
    final practice = Lesson(
      id: 'p1',
      start: DateTime(2026, 10, 12, 17, 40),
      end: DateTime(2026, 10, 12, 19, 25),
      durationSeconds: 105 * 60,
      nightSeconds: 35 * 60,
      miles: 30,
      meet: 'Home',
      notes: 'loop',
      kind: DriveKind.practice,
    );
    final lesson = Lesson(
      id: 'l1',
      start: DateTime(2026, 10, 13, 10),
      end: DateTime(2026, 10, 13, 11),
      durationSeconds: 3600,
      miles: 20,
      kind: DriveKind.instruction,
    );
    final state = AppState(
      store: MemoryStore(
        settings: sampleStudent(),
        lessons: [practice, lesson],
      ),
      gps: FakeTripTracker(),
    );
    state.rules = StateRulesRepo.fromJsonString(File('assets/data/state_rules.json').readAsStringSync());
    state.layouts = layouts;
    await state.load();
    final inp = logInputFromApp(state);
    expect(inp.stateCode, 'CA');
    expect(inp.drives.length, 1);
    expect(inp.drives.first.location, 'Home');
    expect(inp.drives.first.notes, 'loop');
    expect(inp.student.permitNumber, '');
    expect(inp.excluded.lessons, 1);
    expect(inp.drives.first.weatherMinutes, 0);
    final csv = renderLogCsv(inp, buildLogDocument(layouts, inp));
    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('date,start,end,minutes'));
    expect(csvCell('=SUM(1)'), "'=SUM(1)");
  });
}

extension on LogInput {
  LogInput copyWithDrives(List<LogDriveInput> drives) => LogInput(
        stateCode: stateCode,
        stateName: stateName,
        student: student,
        mainSupervisor: mainSupervisor,
        drives: drives,
        totals: totals,
        excluded: excluded,
      );
}
