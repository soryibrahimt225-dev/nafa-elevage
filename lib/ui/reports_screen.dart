import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_data.dart';
import '../data/report_builder.dart';
import '../data/report_export.dart';
import '../domain/lots.dart';
import '../domain/report.dart';
import 'theme.dart';
import 'widgets.dart';

/// Rapports : aperçu à l'écran, export PDF et Excel (partage sur
/// téléphone, téléchargement dans le navigateur).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.data, required this.today});
  final AppData data;
  final DateTime today;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final List<ReportKind> _kinds =
      reportKindsFor(widget.data.settings.production!, widget.data.settings.options);
  late ReportKind _kind = _kinds.first;
  late DateTime? _month = DateTime(widget.today.year, widget.today.month);
  String? _lotCode;
  bool _busy = false;

  /// Les 12 derniers mois.
  List<DateTime> get _months => [
        for (var i = 0; i < 12; i++) DateTime(widget.today.year, widget.today.month - i),
      ];

  List<AnimalLot> get _lots => widget.data.lots.animalLots(widget.data.settings.production!);

  bool get _usesPeriod => _kind != ReportKind.lot && _kind != ReportKind.race;

  Report? _build() {
    final b = ReportBuilder(widget.data, today: widget.today);
    if (_kind == ReportKind.lot) {
      final lots = _lots;
      if (lots.isEmpty) return null;
      _lotCode ??= lots.first.code;
      return b.build(_kind, lotCode: _lotCode);
    }
    // Le rapport mensuel porte toujours sur un mois.
    final month = _kind == ReportKind.mensuel ? (_month ?? DateTime(widget.today.year, widget.today.month)) : _month;
    return b.build(_kind, month: month);
  }

  Future<void> _export(Report r, {required bool pdf}) async {
    setState(() => _busy = true);
    try {
      final Uint8List bytes;
      final String name;
      if (pdf) {
        final fonts = ReportFonts.fromBytes(
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
          await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
        );
        final logo = (await rootBundle.load('assets/images/nafa_logo.png')).buffer.asUint8List();
        bytes = await reportToPdf(r, fonts, logo: logo);
        name = r.fileName('pdf');
      } else {
        bytes = reportToXlsx(r);
        name = r.fileName('xlsx');
      }
      await SharePlus.instance.share(ShareParams(
        title: r.title,
        files: [
          XFile.fromData(bytes,
              name: name,
              mimeType: pdf ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
        ],
        fileNameOverrides: [name],
      ));
    } catch (e) {
      if (mounted) showError(context, 'Export impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge(
            [widget.data.lots, widget.data.finance, widget.data.eggs, widget.data.feed, widget.data.health]),
        builder: (context, _) {
          final report = _build();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Rapports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final k in _kinds)
                  ChoiceChip(
                    key: ValueKey('rapport-${k.name}'),
                    label: Text(k.label),
                    selected: k == _kind,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ]),
              const SizedBox(height: 12),
              if (_usesPeriod)
                DropdownButtonFormField<DateTime?>(
                  key: ValueKey('periode-${_kind.name}'),
                  initialValue: _month,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Période', border: OutlineInputBorder()),
                  items: [
                    if (_kind != ReportKind.mensuel) const DropdownMenuItem(value: null, child: Text('Depuis le début')),
                    for (final m in _months) DropdownMenuItem(value: m, child: Text(periodLabel(m))),
                  ],
                  onChanged: (v) => setState(() => _month = v),
                ),
              if (_kind == ReportKind.lot && _lots.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _lotCode ?? _lots.first.code,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lot', border: OutlineInputBorder()),
                  items: [
                    for (final l in _lots)
                      DropdownMenuItem(value: l.code, child: Text('${l.code} · ${l.breed}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _lotCode = v),
                ),
              const SizedBox(height: 12),
              if (report == null)
                const EmptyState(icon: Icons.description_outlined, title: 'Aucun lot', message: 'Créez d’abord un lot.')
              else ...[
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    key: const ValueKey('export-pdf'),
                    onPressed: _busy ? null : () => _export(report, pdf: true),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Exporter en PDF'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('export-excel'),
                    onPressed: _busy ? null : () => _export(report, pdf: false),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Exporter en Excel'),
                  ),
                ]),
                const SizedBox(height: 12),
                ReportView(report: report),
              ],
            ],
          );
        },
      );
}

/// Aperçu d'un rapport à l'écran.
class ReportView extends StatelessWidget {
  const ReportView({super.key, required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(report.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NafaColors.green)),
        Text(report.subtitle, style: const TextStyle(color: NafaColors.textMuted)),
        for (final s in report.sections) ...[
          const SizedBox(height: 12),
          SectionCard(title: s.title, children: [
            for (final (label, v) in s.rows) InfoRow(label, v.display),
            if (s.table != null && s.table!.rows.isEmpty)
              const Text('Aucune donnée sur la période.', style: TextStyle(color: NafaColors.textMuted)),
            if (s.table != null && s.table!.rows.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: NafaColors.text),
                  columns: [
                    for (var i = 0; i < s.table!.headers.length; i++)
                      DataColumn(label: Text(s.table!.headers[i]), numeric: i > 0),
                  ],
                  rows: [
                    for (final row in s.table!.rows) DataRow(cells: [for (final v in row) DataCell(Text(v.display))]),
                    if (s.table!.totals != null)
                      DataRow(cells: [
                        for (final v in s.table!.totals!)
                          DataCell(Text(v.display, style: const TextStyle(fontWeight: FontWeight.w700))),
                      ]),
                  ],
                ),
              ),
            if (s.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(s.note!, style: const TextStyle(color: NafaColors.textMuted, fontSize: 12)),
              ),
          ]),
        ],
      ]);
}
