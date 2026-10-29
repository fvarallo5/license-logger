// State-matched log layouts. ONE spec (docs/log_layouts + assets/data/log_layouts.json)
// drives this builder and the export-report TypeScript renderer.
//
//   buildLogDocument(layouts, input)  spec + drives -> LogDocument
//
// Must produce the same LogDocument as supabase/functions/export-report/log_layout.ts
// for docs/log_layouts/fixtures/input.json (see test/log_layouts_test.dart).
import 'dart:convert';

import 'package:flutter/services.dart';

class Field {
  const Field(this.label, this.value);
  final String label;
  final String value;
  factory Field.fromJson(Map<String, dynamic> j) =>
      Field(j['label'] as String? ?? '', j['value'] as String? ?? '');
}

class LayoutColumn {
  const LayoutColumn({required this.label, required this.key, required this.w, this.group = ''});
  final String label;
  final String key;
  final num w;
  final String group;
  factory LayoutColumn.fromJson(Map<String, dynamic> j) => LayoutColumn(
        label: j['label'] as String? ?? '',
        key: j['key'] as String? ?? '',
        w: j['w'] as num? ?? 1,
        group: j['group'] as String? ?? '',
      );
}

class Panel {
  const Panel({required this.filter, this.title, required this.columns});
  final String filter;
  final String? title;
  final List<LayoutColumn> columns;
  factory Panel.fromJson(Map<String, dynamic> j) => Panel(
        filter: j['filter'] as String? ?? 'all',
        title: j['title'] as String?,
        columns: [
          for (final c in (j['columns'] as List? ?? const []))
            LayoutColumn.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
      );
}

class PageTotal {
  const PageTotal({required this.label, required this.sum});
  final String label;
  final List<String> sum;
  factory PageTotal.fromJson(Map<String, dynamic> j) => PageTotal(
        label: j['label'] as String? ?? '',
        sum: [for (final s in (j['sum'] as List? ?? const [])) s as String],
      );
}

class TableSpec {
  const TableSpec({
    required this.panels,
    required this.rows,
    required this.rowsFirst,
    this.title,
    this.pageTotal,
    this.exampleRow,
  });
  final List<Panel> panels;
  final int rows;
  final int rowsFirst;
  final String? title;
  final PageTotal? pageTotal;
  final String? exampleRow;
  factory TableSpec.fromJson(Map<String, dynamic> j) => TableSpec(
        panels: [
          for (final p in (j['panels'] as List? ?? const []))
            Panel.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
        rows: (j['rows'] as num?)?.round() ?? 20,
        rowsFirst: (j['rows_first'] as num?)?.round() ?? (j['rows'] as num?)?.round() ?? 20,
        title: j['title'] as String?,
        pageTotal: j['page_total'] == null
            ? null
            : PageTotal.fromJson(Map<String, dynamic>.from(j['page_total'] as Map)),
        exampleRow: j['example_row'] as String?,
      );
}

class NotarySpec {
  const NotarySpec({required this.title, required this.text, required this.lines});
  final String title;
  final String text;
  final List<String> lines;
  factory NotarySpec.fromJson(Map<String, dynamic> j) => NotarySpec(
        title: j['title'] as String? ?? '',
        text: j['text'] as String? ?? '',
        lines: [for (final l in (j['lines'] as List? ?? const [])) l as String],
      );
}

class Certification {
  const Certification({
    required this.title,
    required this.text,
    required this.fields,
    required this.totals,
    required this.signatures,
    this.notary,
    this.extraText,
  });
  final String title;
  final String text;
  final List<Field> fields;
  final List<Field> totals;
  final List<Field> signatures;
  final NotarySpec? notary;
  final String? extraText;
  factory Certification.fromJson(Map<String, dynamic> j) => Certification(
        title: j['title'] as String? ?? '',
        text: j['text'] as String? ?? '',
        fields: [
          for (final f in (j['fields'] as List? ?? const []))
            Field.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        totals: [
          for (final f in (j['totals'] as List? ?? const []))
            Field.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        signatures: [
          for (final f in (j['signatures'] as List? ?? const []))
            Field.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        notary: j['notary'] == null
            ? null
            : NotarySpec.fromJson(Map<String, dynamic>.from(j['notary'] as Map)),
        extraText: j['extra_text'] as String?,
      );
}

class Acceptance {
  const Acceptance({required this.mode, required this.basis, required this.source});
  final String mode;
  final String basis;
  final String source;
  factory Acceptance.fromJson(Map<String, dynamic> j) => Acceptance(
        mode: j['mode'] as String? ?? 'check',
        basis: j['basis'] as String? ?? '',
        source: j['source'] as String? ?? '',
      );
}

class FormSpec {
  const FormSpec({
    required this.name,
    required this.number,
    required this.revision,
    required this.sourcePdf,
    required this.sourcePages,
    required this.url,
  });
  final String name;
  final String number;
  final String revision;
  final String sourcePdf;
  final List<int> sourcePages;
  final String url;
  factory FormSpec.fromJson(Map<String, dynamic> j) => FormSpec(
        name: j['name'] as String? ?? '',
        number: j['number'] as String? ?? '',
        revision: j['revision'] as String? ?? '',
        sourcePdf: j['source_pdf'] as String? ?? '',
        sourcePages: [for (final p in (j['source_pages'] as List? ?? const [])) (p as num).round()],
        url: j['url'] as String? ?? '',
      );
}

class LayoutSpec {
  const LayoutSpec({
    required this.stateCode,
    required this.stateName,
    required this.kind,
    required this.form,
    required this.pageSize,
    required this.orientation,
    required this.title,
    this.subtitle,
    required this.headerFields,
    required this.amountFormat,
    required this.dateFormat,
    required this.tables,
    required this.summary,
    this.certification,
    required this.certPosition,
    this.legend,
    required this.abbrev,
    required this.unfillable,
    required this.notes,
    required this.acceptance,
  });
  final String stateCode;
  final String stateName;
  final String kind;
  final FormSpec form;
  final List<num> pageSize;
  final String orientation;
  final String title;
  final String? subtitle;
  final List<Field> headerFields;
  final String amountFormat;
  final String dateFormat;
  final List<TableSpec> tables;
  final List<Field> summary;
  final Certification? certification;
  final String certPosition;
  final String? legend;
  final Map<String, String> abbrev;
  final List<String> unfillable;
  final List<String> notes;
  final Acceptance acceptance;

  factory LayoutSpec.fromJson(Map<String, dynamic> j) => LayoutSpec(
        stateCode: j['state_code'] as String? ?? '',
        stateName: j['state_name'] as String? ?? '',
        kind: j['kind'] as String? ?? 'full_log',
        form: FormSpec.fromJson(Map<String, dynamic>.from(j['form'] as Map? ?? const {})),
        pageSize: [
          for (final n in (j['page'] is Map ? (j['page'] as Map)['size'] as List? ?? const [612, 792] : const [612, 792]))
            n as num,
        ],
        orientation: j['page'] is Map ? ((j['page'] as Map)['orientation'] as String? ?? 'portrait') : 'portrait',
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String?,
        headerFields: [
          for (final f in (j['header_fields'] as List? ?? const []))
            Field.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        amountFormat: j['amount_format'] as String? ?? 'hr_min',
        dateFormat: j['date_format'] as String? ?? 'm/d/yy',
        tables: [
          for (final t in (j['tables'] as List? ?? const []))
            TableSpec.fromJson(Map<String, dynamic>.from(t as Map)),
        ],
        summary: [
          for (final f in (j['summary'] as List? ?? const []))
            Field.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        certification: j['certification'] == null
            ? null
            : Certification.fromJson(Map<String, dynamic>.from(j['certification'] as Map)),
        certPosition: j['cert_position'] as String? ?? 'after_log',
        legend: j['legend'] as String?,
        abbrev: {
          for (final e in (j['abbrev'] as Map? ?? const {}).entries)
            e.key as String: e.value as String,
        },
        unfillable: [for (final s in (j['unfillable'] as List? ?? const [])) s as String],
        notes: [for (final s in (j['notes'] as List? ?? const [])) s as String],
        acceptance: Acceptance.fromJson(Map<String, dynamic>.from(j['acceptance'] as Map? ?? const {})),
      );
}

class GenericState {
  const GenericState({
    required this.stateName,
    required this.reason,
    required this.form,
    required this.detail,
    this.acceptance,
  });
  final String stateName;
  final String reason;
  final String form;
  final String detail;
  final Acceptance? acceptance;
  factory GenericState.fromJson(Map<String, dynamic> j) => GenericState(
        stateName: j['state_name'] as String? ?? '',
        reason: j['reason'] as String? ?? 'no_form',
        form: j['form'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
        acceptance: j['acceptance'] == null
            ? null
            : Acceptance.fromJson(Map<String, dynamic>.from(j['acceptance'] as Map)),
      );
}

class Layouts {
  const Layouts({
    required this.schema,
    required this.sha256,
    required this.states,
    required this.generic,
    required this.genericStates,
  });
  final String schema;
  final String sha256;
  final Map<String, LayoutSpec> states;
  final LayoutSpec generic;
  final Map<String, GenericState> genericStates;

  static const asset = 'assets/data/log_layouts.json';

  factory Layouts.fromJson(Map<String, dynamic> j) {
    final states = <String, LayoutSpec>{};
    for (final e in (j['states'] as Map).entries) {
      states[e.key as String] = LayoutSpec.fromJson(Map<String, dynamic>.from(e.value as Map));
    }
    final genericStates = <String, GenericState>{};
    for (final e in (j['generic_states'] as Map? ?? const {}).entries) {
      genericStates[e.key as String] =
          GenericState.fromJson(Map<String, dynamic>.from(e.value as Map));
    }
    return Layouts(
      schema: j['schema'] as String? ?? '',
      sha256: j['sha256'] as String? ?? '',
      states: states,
      generic: LayoutSpec.fromJson(Map<String, dynamic>.from(j['generic'] as Map)),
      genericStates: genericStates,
    );
  }

  factory Layouts.fromJsonString(String raw) =>
      Layouts.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  static Future<Layouts> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(asset);
    return Layouts.fromJsonString(raw);
  }
}

class LogDriveInput {
  const LogDriveInput({
    required this.date,
    required this.start,
    required this.end,
    required this.minutes,
    required this.nightMinutes,
    this.weatherMinutes = 0,
    this.weather = '',
    this.roadway = '',
    this.supervisor = '',
    this.initials = '',
    this.skills = const [],
    this.conditions = const [],
    this.location = '',
    this.notes = '',
  });
  final String date;
  final String start;
  final String end;
  final int minutes;
  final int nightMinutes;
  final int weatherMinutes;
  final String weather;
  final String roadway;
  final String supervisor;
  final String initials;
  final List<String> skills;
  final List<String> conditions;
  final String location;
  final String notes;

  factory LogDriveInput.fromJson(Map<String, dynamic> j) => LogDriveInput(
        date: j['date'] as String? ?? '',
        start: j['start'] as String? ?? '',
        end: j['end'] as String? ?? '',
        minutes: (j['minutes'] as num?)?.round() ?? 0,
        nightMinutes: (j['night_minutes'] as num?)?.round() ?? 0,
        weatherMinutes: (j['weather_minutes'] as num?)?.round() ?? 0,
        weather: j['weather'] as String? ?? '',
        roadway: j['roadway'] as String? ?? '',
        supervisor: j['supervisor'] as String? ?? '',
        initials: j['initials'] as String? ?? '',
        skills: [for (final s in (j['skills'] as List? ?? const [])) s as String],
        conditions: [for (final s in (j['conditions'] as List? ?? const [])) s as String],
        location: j['location'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
      );
}

class LogStudent {
  const LogStudent({
    required this.first,
    required this.last,
    this.permitNumber = '',
    this.birthday = '',
    this.permitIssued = '',
    this.school = '',
  });
  final String first;
  final String last;
  final String permitNumber;
  final String birthday;
  final String permitIssued;
  final String school;
  factory LogStudent.fromJson(Map<String, dynamic> j) => LogStudent(
        first: j['first'] as String? ?? '',
        last: j['last'] as String? ?? '',
        permitNumber: j['permit_number'] as String? ?? '',
        birthday: j['birthday'] as String? ?? '',
        permitIssued: j['permit_issued'] as String? ?? '',
        school: j['school'] as String? ?? '',
      );
}

class LogTotals {
  const LogTotals({required this.total, required this.day, required this.night, required this.weather});
  final int total;
  final int day;
  final int night;
  final int weather;
  factory LogTotals.fromJson(Map<String, dynamic> j) => LogTotals(
        total: (j['total'] as num?)?.round() ?? 0,
        day: (j['day'] as num?)?.round() ?? 0,
        night: (j['night'] as num?)?.round() ?? 0,
        weather: (j['weather'] as num?)?.round() ?? 0,
      );
}

class LogExcluded {
  const LogExcluded({this.unsignedDrives = 0, this.unsignedMinutes = 0, this.lessons = 0});
  final int unsignedDrives;
  final int unsignedMinutes;
  final int lessons;
  factory LogExcluded.fromJson(Map<String, dynamic> j) => LogExcluded(
        unsignedDrives: (j['unsigned_drives'] as num?)?.round() ?? 0,
        unsignedMinutes: (j['unsigned_minutes'] as num?)?.round() ?? 0,
        lessons: (j['lessons'] as num?)?.round() ?? 0,
      );
}

class LogInput {
  const LogInput({
    required this.stateCode,
    this.stateName,
    required this.student,
    required this.mainSupervisor,
    required this.drives,
    required this.totals,
    this.excluded = const LogExcluded(),
  });
  final String stateCode;
  final String? stateName;
  final LogStudent student;
  final String mainSupervisor;
  final List<LogDriveInput> drives;
  final LogTotals totals;
  final LogExcluded excluded;

  factory LogInput.fromJson(Map<String, dynamic> j) => LogInput(
        stateCode: j['state_code'] as String? ?? '',
        stateName: j['state_name'] as String?,
        student: LogStudent.fromJson(Map<String, dynamic>.from(j['student'] as Map)),
        mainSupervisor: j['main_supervisor'] as String? ?? '',
        drives: [
          for (final d in (j['drives'] as List? ?? const []))
            LogDriveInput.fromJson(Map<String, dynamic>.from(d as Map)),
        ],
        totals: LogTotals.fromJson(Map<String, dynamic>.from(j['totals'] as Map? ?? const {})),
        excluded: LogExcluded.fromJson(Map<String, dynamic>.from(j['excluded'] as Map? ?? const {})),
      );
}

class Item {
  const Item(this.label, this.value);
  final String label;
  final String value;
  Map<String, dynamic> toJson() => {'label': label, 'value': value};
}

class LogColumn {
  const LogColumn({required this.label, required this.group, required this.w, required this.key});
  final String label;
  final String group;
  final num w;
  final String key;
  Map<String, dynamic> toJson() => {'label': label, 'group': group, 'w': w, 'key': key};
}

class LogPanel {
  const LogPanel({required this.title, required this.columns, required this.rows});
  final String title;
  final List<LogColumn> columns;
  final List<List<String>> rows;
  Map<String, dynamic> toJson() => {
        'title': title,
        'columns': [for (final c in columns) c.toJson()],
        'rows': rows,
      };
}

class LogTable {
  const LogTable({
    required this.title,
    required this.rowCount,
    required this.panels,
    this.total,
  });
  final String title;
  final int rowCount;
  final List<LogPanel> panels;
  final ({String label, List<List<String>> cells})? total;
  Map<String, dynamic> toJson() => {
        'title': title,
        'row_count': rowCount,
        'total': total == null ? null : {'label': total!.label, 'cells': total!.cells},
        'panels': [for (final p in panels) p.toJson()],
      };
}

sealed class LogBlock {
  const LogBlock();
  String get type;
  Map<String, dynamic> toJson();
}

class FieldsBlock extends LogBlock {
  const FieldsBlock(this.items);
  final List<Item> items;
  @override
  String get type => 'fields';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'items': [for (final i in items) i.toJson()]};
}

class TableBlock extends LogBlock {
  const TableBlock(this.table);
  final LogTable table;
  @override
  String get type => 'table';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'table': table.toJson()};
}

class TotalsBlock extends LogBlock {
  const TotalsBlock(this.items);
  final List<Item> items;
  @override
  String get type => 'totals';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'items': [for (final i in items) i.toJson()]};
}

class TextBlock extends LogBlock {
  const TextBlock(this.style, this.text);
  final String style;
  final String text;
  @override
  String get type => 'text';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'style': style, 'text': text};
}

class SignaturesBlock extends LogBlock {
  const SignaturesBlock(this.items);
  final List<Item> items;
  @override
  String get type => 'signatures';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'items': [for (final i in items) i.toJson()]};
}

class NotaryBlock extends LogBlock {
  const NotaryBlock({required this.title, required this.text, required this.lines});
  final String title;
  final String text;
  final List<String> lines;
  @override
  String get type => 'notary';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'title': title, 'text': text, 'lines': lines};
}

class ComputedBlock extends LogBlock {
  const ComputedBlock(this.title, this.items);
  final String title;
  final List<Item> items;
  @override
  String get type => 'computed';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'items': [for (final i in items) i.toJson()],
      };
}

class LogPage {
  const LogPage({required this.label, required this.blocks});
  final String label;
  final List<LogBlock> blocks;
  Map<String, dynamic> toJson() => {
        'label': label,
        'blocks': [for (final b in blocks) b.toJson()],
      };
}

class LogDocument {
  const LogDocument({
    required this.schema,
    required this.stateCode,
    required this.stateName,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.formLabel,
    required this.sourcePdf,
    required this.pageWidth,
    required this.pageHeight,
    required this.disclaimer,
    required this.disclaimerMode,
    required this.footer,
    required this.notes,
    required this.unfillable,
    required this.pages,
  });
  final String schema;
  final String stateCode;
  final String stateName;
  final String kind;
  final String title;
  final String subtitle;
  final String formLabel;
  final String sourcePdf;
  final num pageWidth;
  final num pageHeight;
  final String disclaimer;
  final String disclaimerMode;
  final String footer;
  final List<String> notes;
  final List<String> unfillable;
  final List<LogPage> pages;

  Map<String, dynamic> toJson() => {
        'schema': schema,
        'state_code': stateCode,
        'state_name': stateName,
        'kind': kind,
        'title': title,
        'subtitle': subtitle,
        'form_label': formLabel,
        'source_pdf': sourcePdf,
        'page': {'width': pageWidth, 'height': pageHeight},
        'disclaimer': disclaimer,
        'disclaimer_mode': disclaimerMode,
        'footer': footer,
        'notes': notes,
        'unfillable': unfillable,
        'pages': [for (final p in pages) p.toJson()],
      };
}

String pad2(int n) => n < 10 ? '0$n' : '$n';

String fmtAmount(int m, String f) {
  m = m < 0 ? 0 : m;
  final h = m ~/ 60, r = m % 60;
  switch (f) {
    case 'minutes':
      return '$m';
    case 'hm':
      return '$h:${pad2(r)}';
    case 'hours':
      return fmtHours(m);
    default:
      if (h > 0 && r > 0) return '$h hr $r min';
      if (h > 0) return '$h hr';
      return '$r min';
  }
}

String fmtHours(int m) {
  final mm = m < 0 ? 0 : m;
  final hh = ((mm * 100) / 60).round();
  final i = hh ~/ 100, f = hh % 100;
  if (f == 0) return '$i';
  if (f % 10 == 0) return '$i.${f ~/ 10}';
  return '$i.${pad2(f)}';
}

String fmtDate(String iso, String f) {
  if (iso.isEmpty) return '';
  final parts = iso.split('-');
  if (parts.length < 3) return iso;
  final y = int.tryParse(parts[0]) ?? 0;
  final mo = int.tryParse(parts[1]) ?? 0;
  final d = int.tryParse(parts[2]) ?? 0;
  if (f == 'mm/dd/yyyy') return '${pad2(mo)}/${pad2(d)}/$y';
  if (f == 'm/d') return '$mo/$d';
  return '$mo/$d/${pad2(y % 100)}';
}

int toMin(String hhmm) {
  final p = hhmm.split(':');
  final h = int.tryParse(p.isNotEmpty ? p[0] : '') ?? 0;
  final m = int.tryParse(p.length > 1 ? p[1] : '') ?? 0;
  return h * 60 + m;
}

String time12(int min) {
  var m = ((min % 1440) + 1440) % 1440;
  final h = m ~/ 60, r = m % 60;
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$hh:${pad2(r)} ${h < 12 ? 'AM' : 'PM'}';
}

String initialsOf(String name) => name
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase())
    .take(3)
    .join();

class _RowItem {
  const _RowItem({
    required this.d,
    required this.start,
    required this.end,
    required this.day,
    required this.night,
    required this.weather,
    required this.filter,
  });
  final LogDriveInput d;
  final int start;
  final int end;
  final int day;
  final int night;
  final int weather;
  final String filter;
}

class _Stream {
  _Stream(this.items);
  final List<_RowItem> items;
  int pos = 0;
  int cum = 0;
}

List<_RowItem> _itemsFor(List<LogDriveInput> drives, String filter) {
  final out = <_RowItem>[];
  for (final d in drives) {
    final s = toMin(d.start);
    final total = d.minutes < 0 ? 0 : d.minutes;
    final night = ((d.nightMinutes < 0 ? 0 : d.nightMinutes).clamp(0, total)).toInt();
    final day = total - night;
    if (filter == 'all') {
      out.add(_RowItem(
        d: d,
        start: s,
        end: s + total,
        day: day,
        night: night,
        weather: d.weatherMinutes.clamp(0, total).toInt(),
        filter: filter,
      ));
      continue;
    }
    if (filter == 'none') continue;
    final nightFirst = s < 12 * 60;
    final dayStart = nightFirst ? s + night : s;
    final nightStart = nightFirst ? s : s + day;
    if (filter == 'day' && day > 0) {
      out.add(_RowItem(d: d, start: dayStart, end: dayStart + day, day: day, night: 0, weather: 0, filter: filter));
    }
    if (filter == 'night' && night > 0) {
      out.add(_RowItem(d: d, start: nightStart, end: nightStart + night, day: 0, night: night, weather: 0, filter: filter));
    }
  }
  return out;
}

String abbreviate(List<String> skills, Map<String, String> map) {
  final lower = {for (final e in map.entries) e.key.toLowerCase(): e.value};
  final out = <String>[];
  for (final s in skills) {
    final a = lower[s.toLowerCase()] ?? s;
    if (!out.contains(a)) out.add(a);
  }
  return out.join(', ');
}

({LayoutSpec spec, GenericState? generic}) resolveSpec(Layouts layouts, String state) {
  final s = layouts.states[state];
  if (s != null) return (spec: s, generic: null);
  return (spec: layouts.generic, generic: layouts.genericStates[state]);
}

({String text, String mode}) disclaimerFor(
  LayoutSpec spec,
  GenericState? generic,
  String stateName,
  bool isGeneric,
) {
  if (isGeneric) {
    final g = generic;
    if (g == null) {
      return (
        text: 'LicenseLogger generic layout. Check what your licensing office accepts.',
        mode: 'generic',
      );
    }
    if (g.reason == 'blocked') {
      return (
        text:
            'LicenseLogger generic layout: the official $stateName ${g.form} could not be downloaded to copy its layout. Copy these entries onto the official form.',
        mode: 'generic_blocked',
      );
    }
    if (g.reason == 'unconfirmed') {
      return (
        text:
            "LicenseLogger generic layout: $stateName's requirement is unconfirmed (${g.form}). Check with the licensing office before relying on it.",
        mode: 'generic_unconfirmed',
      );
    }
    final acc = g.acceptance;
    final extra = acc != null && acc.mode == 'accepted'
        ? ' $stateName accepts other formats: "${acc.basis}" (${acc.source}).'
        : ' Check what your licensing office accepts.';
    return (
      text:
          'LicenseLogger generic layout: $stateName has no official log form${g.form.isNotEmpty ? ' (${g.form})' : ''}.$extra',
      mode: acc != null && acc.mode == 'accepted' ? 'generic_accepted' : 'generic_no_form',
    );
  }
  final form =
      '$stateName ${spec.form.number.isNotEmpty ? '${spec.form.number} ' : ''}${spec.form.name}';
  final a = spec.acceptance;
  if (a.mode == 'accepted') {
    return (
      text:
          'Prepared with LicenseLogger from the official $form. $stateName accepts other log formats: "${a.basis}" (${a.source}).',
      mode: 'accepted',
    );
  }
  if (a.mode == 'transfer') {
    return (
      text:
          'Filled copy to transfer/print onto the official $form. $stateName accepts only its own form: "${a.basis}" (${a.source}).',
      mode: 'transfer',
    );
  }
  return (
    text: 'Prepared with LicenseLogger from the official $form; check your state accepts this copy.',
    mode: 'check',
  );
}

LogDocument buildLogDocument(Layouts layouts, LogInput input) {
  final resolved = resolveSpec(layouts, input.stateCode);
  final spec = resolved.spec;
  final generic = resolved.generic;
  final isGeneric = !layouts.states.containsKey(input.stateCode);
  final stateName =
      isGeneric ? (generic?.stateName ?? input.stateName ?? input.stateCode) : spec.stateName;
  String fmt(int m) => fmtAmount(m, spec.amountFormat);
  String cellAmt(int m) => m > 0 ? fmt(m) : '';
  final st = input.student;
  final name = '${st.first} ${st.last}'.trim();
  final t = input.totals;
  String value(String key) {
    switch (key) {
      case 'student_name':
        return name;
      case 'student_name_lfm':
        return st.last.isNotEmpty ? '${st.last}, ${st.first}' : st.first;
      case 'student_first':
        return st.first;
      case 'student_last':
        return st.last;
      case 'student_initials':
        return initialsOf(name);
      case 'permit_number':
        return st.permitNumber;
      case 'birthday':
        return fmtDate(st.birthday, spec.dateFormat);
      case 'permit_issued':
        return fmtDate(st.permitIssued, spec.dateFormat);
      case 'school_name':
        return st.school;
      case 'supervisor_name':
        return input.mainSupervisor;
      case 'total':
        return fmt(t.total);
      case 'day':
        return fmt(t.day);
      case 'night':
        return fmt(t.night);
      case 'weather':
        return fmt(t.weather);
      case 'total_minutes':
        return '${t.total}';
      case 'day_minutes':
        return '${t.day}';
      case 'night_minutes':
        return '${t.night}';
      case 'weather_minutes':
        return '${t.weather}';
      case 'total_hours':
        return fmtHours(t.total);
      case 'day_hours':
        return fmtHours(t.day);
      case 'night_hours':
        return fmtHours(t.night);
      default:
        return '';
    }
  }

  List<Item> items(List<Field> fs) => [for (final f in fs) Item(f.label, value(f.value))];
  String fill(String s) =>
      s.replaceAllMapped(RegExp(r'\{([a-z_]+)\}'), (m) {
        final v = value(m[1]!);
        return v.isEmpty ? '________' : v;
      });

  final drives = [...input.drives]..sort((a, b) => (a.date + a.start).compareTo(b.date + b.start));
  String cell(String key, _RowItem it, int cum) {
    final d = it.d;
    switch (key) {
      case 'date':
        return fmtDate(d.date, spec.dateFormat);
      case 'date_time':
        return '${fmtDate(d.date, spec.dateFormat)} ${time12(it.start)}';
      case 'start_time':
        return time12(it.start);
      case 'end_time':
        return time12(it.end);
      case 'time_range':
        return '${time12(it.start)} - ${time12(it.end)}';
      case 'amount':
        return cellAmt(it.day + it.night);
      case 'day_amount':
        return cellAmt(it.day);
      case 'night_amount':
        return cellAmt(it.night);
      case 'weather_amount':
        return cellAmt(it.weather);
      case 'day_hours_part':
        return it.day > 0 ? '${it.day ~/ 60}' : '';
      case 'day_minutes_part':
        return it.day > 0 ? '${it.day % 60}' : '';
      case 'night_hours_part':
        return it.night > 0 ? '${it.night ~/ 60}' : '';
      case 'night_minutes_part':
        return it.night > 0 ? '${it.night % 60}' : '';
      case 'day_or_night':
        return it.night == 0
            ? 'Day'
            : it.day == 0
                ? 'Night'
                : 'Day + Night';
      case 'cumulative':
        return fmt(cum);
      case 'weather':
        return d.weather;
      case 'roadway':
        return d.roadway;
      case 'conditions':
        return d.conditions.join(', ');
      case 'conditions_skills':
        return [...d.conditions, ...d.skills].join(', ');
      case 'location':
        return d.location;
      case 'skills':
        return d.skills.join(', ');
      case 'skills_abbrev':
        return abbreviate(d.skills, spec.abbrev);
      case 'supervisor_name':
        return d.supervisor;
      case 'supervisor_initials':
        return d.initials;
      case 'student_initials':
        return initialsOf(name);
      case 'notes':
        return d.notes;
      default:
        return '';
    }
  }

  int minutesOf(String key, _RowItem it) {
    switch (key) {
      case 'amount':
        return it.day + it.night;
      case 'day_amount':
        return it.day;
      case 'night_amount':
        return it.night;
      case 'weather_amount':
        return it.weather;
      default:
        return 0;
    }
  }

  final logPages = <List<LogBlock>>[];
  final tables = spec.kind == 'certification' ? <TableSpec>[] : spec.tables;
  for (final tb in tables) {
    final streams = <String, _Stream>{};
    for (final p in tb.panels) {
      streams.putIfAbsent(p.filter, () => _Stream(_itemsFor(drives, p.filter)));
    }
    var page = 0;
    var more = true;
    while (more) {
      final cap = page == 0 ? tb.rowsFirst : tb.rows;
      final built = <({Panel panel, List<List<String>> rows, Map<String, int> sums})>[];
      for (final p in tb.panels) {
        final s = streams[p.filter]!;
        final rows = <List<String>>[];
        final sums = <String, int>{};
        for (var i = 0; i < cap && s.pos < s.items.length; i++, s.pos++) {
          final it = s.items[s.pos];
          s.cum += it.day + it.night;
          rows.add([for (final c in p.columns) cell(c.key, it, s.cum)]);
          for (final c in p.columns) {
            sums[c.key] = (sums[c.key] ?? 0) + minutesOf(c.key, it);
          }
        }
        built.add((panel: p, rows: rows, sums: sums));
      }
      final total = tb.pageTotal == null
          ? null
          : (
              label: tb.pageTotal!.label,
              cells: [
                for (final b in built)
                  [
                    for (final c in b.panel.columns)
                      tb.pageTotal!.sum.contains(c.key) ? fmt(b.sums[c.key] ?? 0) : '',
                  ],
              ],
            );
      logPages.add([
        TableBlock(
          LogTable(
            title: tb.title ?? '',
            rowCount: cap,
            total: total,
            panels: [
              for (final b in built)
                LogPanel(
                  title: b.panel.title ?? '',
                  columns: [
                    for (final c in b.panel.columns)
                      LogColumn(label: c.label, group: c.group, w: c.w, key: c.key),
                  ],
                  rows: b.rows,
                ),
            ],
          ),
        ),
      ]);
      page++;
      more = streams.values.any((s) => s.pos < s.items.length);
    }
  }

  final certBlocks = <LogBlock>[];
  final c = spec.certification;
  if (c != null) {
    if (c.title.isNotEmpty) certBlocks.add(TextBlock('heading', c.title));
    if (c.fields.isNotEmpty) certBlocks.add(FieldsBlock(items(c.fields)));
    if (c.totals.isNotEmpty) certBlocks.add(TotalsBlock(items(c.totals)));
    if (c.text.isNotEmpty) certBlocks.add(TextBlock('cert', fill(c.text)));
    if ((c.extraText ?? '').isNotEmpty) certBlocks.add(TextBlock('cert', fill(c.extraText!)));
    if (c.signatures.isNotEmpty) certBlocks.add(SignaturesBlock(items(c.signatures)));
    if (c.notary != null) {
      certBlocks.add(NotaryBlock(title: c.notary!.title, text: fill(c.notary!.text), lines: c.notary!.lines));
    }
  }
  final summaryBlocks =
      spec.summary.isNotEmpty ? <LogBlock>[TotalsBlock(items(spec.summary))] : <LogBlock>[];
  final legendBlocks =
      spec.legend != null && spec.legend!.isNotEmpty ? <LogBlock>[TextBlock('legend', spec.legend!)] : <LogBlock>[];
  final computedItems = <Item>[
    Item('Credited total', fmt(t.total)),
    Item('Day', fmt(t.day)),
    Item('Night', fmt(t.night)),
    if (t.weather > 0) Item('Bad weather', fmt(t.weather)),
    Item('Signed drives listed', '${drives.length}'),
    if (input.excluded.unsignedDrives > 0)
      Item('Not listed: unsigned', '${input.excluded.unsignedDrives} (${fmt(input.excluded.unsignedMinutes)})'),
    if (input.excluded.lessons > 0) Item('Not listed: school lessons', '${input.excluded.lessons}'),
  ];
  const computedTitle = 'Computed by LicenseLogger (not part of the official form)';
  final computed = ComputedBlock(computedTitle, computedItems);
  final header =
      spec.headerFields.isNotEmpty ? <LogBlock>[FieldsBlock(items(spec.headerFields))] : <LogBlock>[];

  final pages = <List<LogBlock>>[];
  if (spec.kind == 'certification') {
    final p1 = <LogBlock>[...header, ...certBlocks];
    for (final tb in spec.tables) {
      p1.add(
        TableBlock(
          LogTable(
            title: tb.title ?? '',
            rowCount: tb.rows,
            total: null,
            panels: [
              for (final p in tb.panels)
                LogPanel(
                  title: p.title ?? '',
                  columns: [
                    for (final c in p.columns)
                      LogColumn(label: c.label, group: c.group, w: c.w, key: c.key),
                  ],
                  rows: const [],
                ),
            ],
          ),
        ),
      );
    }
    p1.add(computed);
    pages.add(p1);
    final g = layouts.generic.tables[0];
    final cols = g.panels[0].columns;
    final its = _itemsFor(drives, 'all');
    for (var i = 0, cum = 0; i == 0 || i < its.length; i += g.rows) {
      final slice = its.skip(i).take(g.rows);
      final rows = <List<String>>[];
      for (final it in slice) {
        cum += it.day + it.night;
        rows.add([for (final c in cols) cell(c.key, it, cum)]);
      }
      pages.add([
        const TextBlock('heading', 'Supporting drive record (LicenseLogger; not part of the official form)'),
        TableBlock(
          LogTable(
            title: '',
            rowCount: rows.isEmpty ? 1 : rows.length,
            total: null,
            panels: [
              LogPanel(
                title: '',
                columns: [
                  for (final c in cols) LogColumn(label: c.label, group: '', w: c.w, key: c.key),
                ],
                rows: rows,
              ),
            ],
          ),
        ),
      ]);
      if (its.isEmpty) break;
    }
  } else if (spec.certPosition == 'before_log') {
    pages.add([...header, ...certBlocks]);
    for (var i = 0; i < logPages.length; i++) {
      pages.add(i == 0 ? [...logPages[i], ...legendBlocks] : [...logPages[i]]);
    }
    pages[pages.length - 1].addAll([...summaryBlocks, computed]);
  } else {
    for (var i = 0; i < logPages.length; i++) {
      pages.add(i == 0 ? [...logPages[i], ...legendBlocks] : [...logPages[i]]);
    }
    if (pages.isEmpty) pages.add([]);
    pages[0].insertAll(0, header);
    pages[pages.length - 1].addAll([...summaryBlocks, ...certBlocks, computed]);
  }

  final d = disclaimerFor(spec, generic, stateName, isGeneric);
  final n = pages.length;
  final formLabel = isGeneric
      ? (generic?.form ?? '')
      : [
          spec.form.number,
          if (spec.form.revision.isNotEmpty) '(${spec.form.revision})',
        ].where((x) => x.isNotEmpty).join(' ');
  return LogDocument(
    schema: 'licenselogger.log_document/v1',
    stateCode: input.stateCode,
    stateName: stateName,
    kind: isGeneric ? 'generic' : spec.kind,
    title: spec.title,
    subtitle: spec.subtitle ?? '',
    formLabel: formLabel,
    sourcePdf: isGeneric ? '' : spec.form.sourcePdf,
    pageWidth: spec.pageSize.isNotEmpty ? spec.pageSize[0] : 612,
    pageHeight: spec.pageSize.length > 1 ? spec.pageSize[1] : 792,
    disclaimer: d.text,
    disclaimerMode: d.mode,
    footer: '$name - prepared with LicenseLogger',
    notes: isGeneric && generic != null ? [generic.detail, ...spec.notes] : spec.notes,
    unfillable: spec.unfillable,
    pages: [
      for (var i = 0; i < pages.length; i++)
        LogPage(label: 'Page ${i + 1} of $n', blocks: pages[i]),
    ],
  );
}

String bannerTitleFor(String mode) {
  switch (mode) {
    case 'accepted':
      return 'Official layout · other formats accepted';
    case 'transfer':
      return 'Copy onto the official form';
    case 'check':
      return 'Official layout · check acceptance';
    default:
      return 'Generic layout · check with your office';
  }
}
