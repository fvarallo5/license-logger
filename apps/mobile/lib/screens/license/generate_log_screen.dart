import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/log_export.dart';
import '../../data/log_layouts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ll_widgets.dart';
import '../../state/app_state.dart';

/// Preview + local PDF/CSV of the state-matched log.
class GenerateLogScreen extends StatefulWidget {
  const GenerateLogScreen({super.key});

  @override
  State<GenerateLogScreen> createState() => _GenerateLogScreenState();
}

class _GenerateLogScreenState extends State<GenerateLogScreen> {
  int _page = 0;
  bool _busy = false;

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final layouts = app.layouts;
    if (layouts == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Generate my log'), backgroundColor: Colors.transparent),
        body: const Center(child: Text('Could not load log layouts.')),
      );
    }
    final input = logInputFromApp(app);
    if (input.stateCode.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Generate my log'), backgroundColor: Colors.transparent),
        body: const Center(child: Text('Pick your state in profile first.')),
      );
    }
    final doc = buildLogDocument(layouts, input);
    final page = doc.pages[_page.clamp(0, doc.pages.length - 1)];
    final banner = bannerTitleFor(doc.disclaimerMode);
    final transfer = doc.disclaimerMode == 'transfer';

    return Scaffold(
      backgroundColor: LL.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          children: [
            Text('Generate my log', style: llText(LL.fsLg, weight: FontWeight.w600)),
            Text(
              doc.formLabel.isNotEmpty ? doc.formLabel : doc.stateName,
              style: llText(LL.fsSm, color: LL.textMuted),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(LL.s4, 0, LL.s4, 120),
        children: [
          LLCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  transfer ? Icons.description_rounded : Icons.description_outlined,
                  color: LL.primary,
                  size: 22,
                ),
                const SizedBox(width: LL.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(banner, style: llText(LL.fsSm, weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(doc.disclaimer, style: llText(LL.fsSm, color: LL.textMuted, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (doc.pages.length > 1) ...[
            const SizedBox(height: LL.s3),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < doc.pages.length; i++)
                  _PageChip(
                    label: 'Page ${i + 1}',
                    selected: i == _page,
                    onTap: () => setState(() => _page = i),
                  ),
              ],
            ),
          ],
          const SizedBox(height: LL.s3),
          LLCard(
            padding: const EdgeInsets.all(LL.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${doc.stateName.toUpperCase()}${doc.formLabel.isNotEmpty ? '  |  ${doc.formLabel}' : ''}',
                  style: llText(LL.fsXs, color: LL.textMuted, letterSpacing: 0.4),
                ),
                if (doc.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(doc.subtitle, style: llText(LL.fsXs, weight: FontWeight.w600, color: LL.textMuted)),
                ],
                const SizedBox(height: 4),
                Text(doc.title, style: llText(LL.fsMd, weight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 4),
                Text(doc.disclaimer, style: llText(11, color: LL.primary, height: 1.35)),
                const SizedBox(height: LL.s3),
                for (final b in page.blocks) _BlockView(block: b),
                const SizedBox(height: LL.s2),
                Text(
                  '${doc.footer}  |  ${page.label}',
                  style: llText(11, color: LL.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: LL.s3),
          Text(
            doc.sourcePdf.isEmpty
                ? 'Generic layout · ${doc.pages.length} page${doc.pages.length == 1 ? '' : 's'} · same layout file as the PDF export.'
                : 'Layout copied from ${doc.sourcePdf} · ${doc.pages.length} page${doc.pages.length == 1 ? '' : 's'} · same layout file as the PDF export.',
            style: llText(LL.fsSm, color: LL.textMuted, height: 1.4),
          ),
          if (doc.unfillable.isNotEmpty || doc.notes.isNotEmpty) ...[
            const SizedBox(height: LL.s4),
            LLCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NOTES ON THIS COPY', style: llLabel()),
                  const SizedBox(height: LL.s2),
                  for (final u in doc.unfillable)
                    _NoteLine('Left blank: $u'),
                  for (final n in doc.notes) _NoteLine(n),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Material(
        color: LL.bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(LL.s4, LL.s2, LL.s4, LL.s3),
            child: Row(
              children: [
                Expanded(
                  child: LLButton(
                    'CSV',
                    kind: BtnKind.secondary,
                    icon: Icons.table_chart_outlined,
                    expand: true,
                    onPressed: _busy ? null : () => _run(() => shareLogCsv(input, doc)),
                  ),
                ),
                const SizedBox(width: LL.s3),
                Expanded(
                  flex: 2,
                  child: LLButton(
                    'Export PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    expand: true,
                    onPressed: _busy ? null : () => _run(() => shareLogPdf(doc)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageChip extends StatelessWidget {
  const _PageChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? LL.accent : LL.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? LL.accent : LL.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 16, color: LL.text),
                const SizedBox(width: 4),
              ],
              Text(label, style: llText(LL.fsSm, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: llText(LL.fsSm, color: LL.textMuted)),
          Expanded(child: Text(text, style: llText(LL.fsSm, height: 1.4))),
        ],
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});
  final LogBlock block;

  @override
  Widget build(BuildContext context) {
    switch (block) {
      case FieldsBlock(:final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final it in items)
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 140, maxWidth: 280),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${it.label} ', style: llText(11, color: LL.textMuted)),
                      Flexible(
                        child: Text(
                          it.value.isEmpty ? '________' : it.value,
                          style: llText(11, weight: FontWeight.w600, color: LL.primary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case TableBlock(:final table):
        return _TablePreview(table: table);
      case TotalsBlock(:final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(it.label, style: llText(12, weight: FontWeight.w600))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: LL.borderStrong)),
                        child: Text(it.value, style: llText(12, weight: FontWeight.w700, color: LL.primary)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case TextBlock(:final style, :final text):
        if (style == 'heading') {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(text, style: llText(LL.fsSm, weight: FontWeight.w700)),
          );
        }
        if (style == 'legend') {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(text, style: llText(11, color: LL.textMuted, height: 1.35)),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: llText(12, height: 1.4)),
        );
      case SignaturesBlock(:final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final it in items)
                SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: LL.text)),
                        ),
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          it.value,
                          style: llText(12, weight: FontWeight.w600, color: LL.primary),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(it.label, style: llText(10, color: LL.textMuted, height: 1.25)),
                    ],
                  ),
                ),
            ],
          ),
        );
      case NotaryBlock(:final title, :final text, :final lines):
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: LL.text, width: 1.2)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty) Text(title, style: llText(12, weight: FontWeight.w700)),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(text, style: llText(11, height: 1.35)),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  for (final l in lines)
                    SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: LL.text, height: 12),
                          Text(l, style: llText(10, color: LL.textMuted)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      case ComputedBlock(:final title, :final items):
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F7FF),
            border: Border.all(color: LL.primary, width: 1, strokeAlign: BorderSide.strokeAlignInside),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: llText(12, weight: FontWeight.w700, color: LL.primary)),
              const SizedBox(height: 4),
              Text(
                items.map((i) => '${i.label}: ${i.value}').join('  |  '),
                style: llText(11, height: 1.4),
              ),
            ],
          ),
        );
    }
  }
}

class _TablePreview extends StatelessWidget {
  const _TablePreview({required this.table});
  final LogTable table;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (table.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(table.title, style: llText(LL.fsSm, weight: FontWeight.w700)),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < table.panels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  _PanelTable(table: table, panel: table.panels[i], panelIndex: i),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTable extends StatelessWidget {
  const _PanelTable({required this.table, required this.panel, required this.panelIndex});
  final LogTable table;
  final LogPanel panel;
  final int panelIndex;

  @override
  Widget build(BuildContext context) {
    final hasGroup = panel.columns.any((c) => c.group.isNotEmpty);
    final filled = panel.rows.length;
    final blank = (table.rowCount - filled).clamp(0, table.rowCount);
    final totalCells =
        table.total != null && panelIndex < table.total!.cells.length ? table.total!.cells[panelIndex] : const <String>[];

    TextStyle head = llText(9, weight: FontWeight.w700, height: 1.15);
    TextStyle cell = llText(10, color: LL.primary, height: 1.2);
    BorderSide side = const BorderSide(color: LL.text, width: 0.6);

    Widget box(Widget child, {Color? bg, bool last = false}) {
      return Container(
        constraints: const BoxConstraints(minWidth: 36),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: side,
            left: side,
            right: last ? side : BorderSide.none,
            bottom: side,
          ),
        ),
        child: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (panel.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(panel.title, style: llText(11, weight: FontWeight.w700)),
          ),
        Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            if (hasGroup)
              TableRow(
                children: [
                  for (var i = 0; i < panel.columns.length; i++)
                    box(
                      Text(
                        i == 0 || panel.columns[i].group != panel.columns[i - 1].group
                            ? panel.columns[i].group
                            : '',
                        style: head,
                      ),
                      bg: LL.surface2,
                      last: i == panel.columns.length - 1,
                    ),
                ],
              ),
            TableRow(
              children: [
                for (var i = 0; i < panel.columns.length; i++)
                  box(
                    Text(panel.columns[i].label, style: head),
                    bg: LL.surface2,
                    last: i == panel.columns.length - 1,
                  ),
              ],
            ),
            for (final row in panel.rows)
              TableRow(
                children: [
                  for (var i = 0; i < panel.columns.length; i++)
                    box(
                      Text(i < row.length ? row[i] : '', style: cell),
                      last: i == panel.columns.length - 1,
                    ),
                ],
              ),
            if (table.total != null)
              TableRow(
                children: [
                  for (var i = 0; i < panel.columns.length; i++)
                    box(
                      Text(
                        i == 0 ? table.total!.label : (i < totalCells.length ? totalCells[i] : ''),
                        style: llText(10, weight: FontWeight.w700, color: i == 0 ? LL.text : LL.primary),
                      ),
                      bg: LL.surface2,
                      last: i == panel.columns.length - 1,
                    ),
                ],
              ),
          ],
        ),
        if (blank > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${table.rowCount} rows on the official page; $blank more blank rows not shown',
              style: llText(10, color: LL.textMuted),
            ),
          ),
      ],
    );
  }
}
