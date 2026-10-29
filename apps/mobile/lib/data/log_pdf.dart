// Readable PDF of a LogDocument. Structure follows
// supabase/functions/export-report/log_layout.ts renderStateLogPdf;
// pixels do not need to match the TypeScript samples.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'log_layouts.dart';

const _ink = PdfColor.fromInt(0xFF141A24);
const _grey = PdfColor.fromInt(0xFF666E7A);
const _line = PdfColor.fromInt(0xFF40454D);
const _shade = PdfColor.fromInt(0xFFEEEFF4);
const _blue = PdfColor.fromInt(0xFF124E9E);

String pdfSafe(String s) => s
    .replaceAll(RegExp('[\u2013\u2014]'), '-')
    .replaceAll(RegExp('[\u2018\u2019]'), "'")
    .replaceAll(RegExp('[\u201C\u201D]'), '"')
    .replaceAll('\u2265', '>=')
    .replaceAllMapped(RegExp(r'[^\x20-\x7E\u00A0-\u00FF]'), (_) => '?');

Future<Uint8List> renderStateLogPdf(
  LogDocument d, {
  required String generatedAt,
  required String exportId,
}) async {
  final pdf = pw.Document(
    title: pdfSafe('${d.stateName} ${d.formLabel} ${d.title}'.trim()),
    author: 'LicenseLogger',
    creator: 'LicenseLogger',
  );
  final format = PdfPageFormat(d.pageWidth.toDouble(), d.pageHeight.toDouble());
  final m = (format.width < format.height ? format.width : format.height) * 0.055;
  final margin = m.clamp(20.0, 40.0);
  final base = pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: _ink);
  final bold = pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8, color: _ink);

  for (var i = 0; i < d.pages.length; i++) {
    final page = d.pages[i];
    final last = i == d.pages.length - 1;
    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: pw.EdgeInsets.all(margin),
        footer: (ctx) => pw.Text(
          pdfSafe('${d.footer}  |  export $exportId  |  $generatedAt  |  ${page.label}'),
          style: base.copyWith(fontSize: 6.5, color: _grey),
        ),
        build: (ctx) {
          final out = <pw.Widget>[];
          if (i == 0) {
            out.add(pw.Text(
              pdfSafe('${d.stateName.toUpperCase()}${d.formLabel.isNotEmpty ? '  |  ${d.formLabel}' : ''}'),
              style: base.copyWith(fontSize: 7, color: _grey),
            ));
            if (d.subtitle.isNotEmpty) {
              out.add(pw.SizedBox(height: 4));
              out.add(pw.Text(pdfSafe(d.subtitle), style: bold.copyWith(fontSize: 8, color: _grey)));
            }
            out.add(pw.SizedBox(height: 4));
            out.add(pw.Text(pdfSafe(d.title), style: bold.copyWith(fontSize: format.width < 450 ? 12 : 14)));
            out.add(pw.SizedBox(height: 4));
            out.add(pw.Text(pdfSafe(d.disclaimer), style: base.copyWith(fontSize: 7.5, color: _blue)));
            out.add(pw.SizedBox(height: 8));
          } else {
            out.add(pw.Text(
              pdfSafe('${d.title}${d.formLabel.isNotEmpty ? '  -  ${d.formLabel}' : ''}'),
              style: bold.copyWith(fontSize: 8, color: _grey),
            ));
            out.add(pw.SizedBox(height: 10));
          }
          for (final b in page.blocks) {
            out.addAll(_block(b, base, bold, format.width));
          }
          if (last && (d.unfillable.isNotEmpty || d.notes.isNotEmpty)) {
            out.add(pw.SizedBox(height: 8));
            out.add(pw.Text('Notes on this copy', style: bold.copyWith(fontSize: 7.5, color: _grey)));
            if (d.unfillable.isNotEmpty) {
              out.add(pw.Text(
                pdfSafe('Left blank for you to fill by hand: ${d.unfillable.join('; ')}.'),
                style: base.copyWith(fontSize: 6.5, color: _grey),
              ));
            }
            for (final n in d.notes) {
              out.add(pw.Text(pdfSafe(n), style: base.copyWith(fontSize: 6.5, color: _grey)));
            }
          }
          return out;
        },
      ),
    );
  }
  return Uint8List.fromList(await pdf.save());
}

List<pw.Widget> _block(LogBlock b, pw.TextStyle base, pw.TextStyle bold, double pageW) {
  switch (b) {
    case FieldsBlock(:final items):
      return [_fields(items, base, bold)];
    case TableBlock(:final table):
      return [_table(table, base, bold)];
    case TotalsBlock(:final items):
      return [
        for (final it in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.RichText(
              text: pw.TextSpan(children: [
                pw.TextSpan(text: '${pdfSafe(it.label)}  ', style: bold.copyWith(fontSize: 8)),
                pw.TextSpan(text: pdfSafe(it.value), style: bold.copyWith(fontSize: 8.5, color: _blue)),
              ]),
            ),
          ),
        pw.SizedBox(height: 4),
      ];
    case TextBlock(:final style, :final text):
      if (style == 'heading') {
        return [
          pw.SizedBox(height: 4),
          pw.Text(pdfSafe(text), style: bold.copyWith(fontSize: 10)),
          pw.SizedBox(height: 4),
        ];
      }
      if (style == 'legend') {
        return [
          pw.Text(pdfSafe(text), style: base.copyWith(fontSize: 6.5, color: _grey)),
          pw.SizedBox(height: 6),
        ];
      }
      return [
        pw.Text(pdfSafe(text), style: base.copyWith(fontSize: 8, lineSpacing: 1.5)),
        pw.SizedBox(height: 6),
      ];
    case SignaturesBlock(:final items):
      return [_signatures(items, base, bold, pageW)];
    case NotaryBlock(:final title, :final text, :final lines):
      return [_notary(title, text, lines, base, bold)];
    case ComputedBlock(:final title, :final items):
      final body = items.map((i) => '${i.label}: ${i.value}').join('   |   ');
      return [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF2F7FF),
            border: pw.Border.all(color: _blue, width: 0.6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(pdfSafe(title), style: bold.copyWith(fontSize: 7, color: _blue)),
              pw.SizedBox(height: 2),
              pw.Text(pdfSafe(body), style: base.copyWith(fontSize: 7)),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
      ];
  }
}

pw.Widget _fields(List<Item> items, pw.TextStyle base, pw.TextStyle bold) {
  pw.Widget cell(Item it) => pw.Padding(
        padding: const pw.EdgeInsets.only(right: 8, bottom: 6),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(text: '${pdfSafe(it.label)} ', style: base.copyWith(fontSize: 7.5, color: _grey)),
            pw.TextSpan(text: pdfSafe(it.value), style: bold.copyWith(fontSize: 8, color: _blue)),
          ]),
        ),
      );
  final rows = <pw.TableRow>[];
  for (var i = 0; i < items.length; i += 2) {
    final left = cell(items[i]);
    final right = i + 1 < items.length ? cell(items[i + 1]) : pw.SizedBox();
    rows.add(pw.TableRow(children: [left, right]));
  }
  return pw.Table(columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FlexColumnWidth()}, children: rows);
}

pw.Widget _table(LogTable t, pw.TextStyle base, pw.TextStyle bold) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (t.title.isNotEmpty) ...[
        pw.Text(pdfSafe(t.title), style: bold.copyWith(fontSize: 10)),
        pw.SizedBox(height: 4),
      ],
      for (var pi = 0; pi < t.panels.length; pi++) ...[
        if (pi > 0) pw.SizedBox(height: 6),
        _panel(t, t.panels[pi], pi, base, bold),
      ],
      pw.SizedBox(height: 8),
    ],
  );
}

pw.Widget _panel(LogTable t, LogPanel p, int pi, pw.TextStyle base, pw.TextStyle bold) {
  final hasGroup = p.columns.any((c) => c.group.isNotEmpty);
  final rows = <pw.TableRow>[];
  if (p.title.isNotEmpty) {
    rows.add(
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(2),
            child: pw.Text(pdfSafe(p.title), style: bold.copyWith(fontSize: 8)),
          ),
          for (var i = 1; i < p.columns.length; i++) pw.SizedBox(),
        ],
      ),
    );
  }
  if (hasGroup) {
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _shade),
        children: [
          for (var ci = 0; ci < p.columns.length; ci++)
            pw.Padding(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text(
                pdfSafe(
                  ci == 0 || p.columns[ci].group != p.columns[ci - 1].group ? p.columns[ci].group : '',
                ),
                style: bold.copyWith(fontSize: 6.5),
              ),
            ),
        ],
      ),
    );
  }
  rows.add(
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _shade),
      children: [
        for (final c in p.columns)
          pw.Padding(
            padding: const pw.EdgeInsets.all(2),
            child: pw.Text(pdfSafe(c.label), style: bold.copyWith(fontSize: 6.5)),
          ),
      ],
    ),
  );
  final show = t.rowCount < p.rows.length ? t.rowCount : p.rows.length;
  final n = t.rowCount > show ? t.rowCount : show;
  for (var i = 0; i < n; i++) {
    final row = i < p.rows.length ? p.rows[i] : const <String>[];
    rows.add(
      pw.TableRow(
        children: [
          for (var ci = 0; ci < p.columns.length; ci++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
              child: pw.Text(
                pdfSafe(ci < row.length ? row[ci] : ''),
                style: base.copyWith(fontSize: 7, color: _blue),
              ),
            ),
        ],
      ),
    );
  }
  if (t.total != null) {
    final cells = pi < t.total!.cells.length ? t.total!.cells[pi] : const <String>[];
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _shade),
        children: [
          for (var ci = 0; ci < p.columns.length; ci++)
            pw.Padding(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text(
                pdfSafe(ci == 0 ? t.total!.label : (ci < cells.length ? cells[ci] : '')),
                style: bold.copyWith(fontSize: 7, color: ci == 0 ? _ink : _blue),
              ),
            ),
        ],
      ),
    );
  }
  final widths = <int, pw.TableColumnWidth>{};
  final sw = p.columns.fold<num>(0, (a, c) => a + c.w);
  for (var i = 0; i < p.columns.length; i++) {
    widths[i] = pw.FlexColumnWidth(p.columns[i].w.toDouble() / (sw == 0 ? 1 : sw.toDouble()));
  }
  return pw.Table(
    border: pw.TableBorder.all(color: _line, width: 0.4),
    columnWidths: widths,
    children: rows,
  );
}

pw.Widget _signatures(List<Item> items, pw.TextStyle base, pw.TextStyle bold, double pageW) {
  pw.Widget one(Item it) => pw.Padding(
        padding: const pw.EdgeInsets.only(right: 12, bottom: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.6)),
              ),
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(pdfSafe(it.value), style: bold.copyWith(fontSize: 9, color: _blue)),
            ),
            pw.SizedBox(height: 2),
            pw.Text(pdfSafe(it.label), style: base.copyWith(fontSize: 6.5, color: _grey)),
          ],
        ),
      );
  final cols = pageW > 500 ? 2 : 1;
  final rows = <pw.TableRow>[];
  for (var i = 0; i < items.length; i += cols) {
    if (cols == 1) {
      rows.add(pw.TableRow(children: [one(items[i])]));
    } else {
      rows.add(pw.TableRow(children: [
        one(items[i]),
        i + 1 < items.length ? one(items[i + 1]) : pw.SizedBox(),
      ]));
    }
  }
  return pw.Table(
    columnWidths: cols == 1
        ? const {0: pw.FlexColumnWidth()}
        : const {0: pw.FlexColumnWidth(), 1: pw.FlexColumnWidth()},
    children: rows,
  );
}

pw.Widget _notaryLine(String l, pw.TextStyle base) => pw.Padding(
      padding: const pw.EdgeInsets.only(right: 10, bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.5)),
            ),
            height: 14,
          ),
          pw.Text(pdfSafe(l), style: base.copyWith(fontSize: 6.5, color: _grey)),
        ],
      ),
    );

pw.Widget _notary(String title, String text, List<String> lines, pw.TextStyle base, pw.TextStyle bold) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(8),
    margin: const pw.EdgeInsets.only(bottom: 8),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 0.8)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) pw.Text(pdfSafe(title), style: bold.copyWith(fontSize: 8)),
        if (text.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(pdfSafe(text), style: base.copyWith(fontSize: 7.5)),
        ],
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FlexColumnWidth()},
          children: [
            for (var i = 0; i < lines.length; i += 2)
              pw.TableRow(children: [
                _notaryLine(lines[i], base),
                i + 1 < lines.length ? _notaryLine(lines[i + 1], base) : pw.SizedBox(),
              ]),
          ],
        ),
      ],
    ),
  );
}
