import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/report.dart';

/// Polices des PDF (Roboto, prend en charge les accents, « œ » et « ’ »).
class ReportFonts {
  const ReportFonts(this.regular, this.bold);
  final pw.Font regular;
  final pw.Font bold;

  factory ReportFonts.fromBytes(ByteData regular, ByteData bold) =>
      ReportFonts(pw.Font.ttf(regular), pw.Font.ttf(bold));
}

const _green = PdfColor.fromInt(0xFF064A28);
const _muted = PdfColor.fromInt(0xFF5D6B61);
const _light = PdfColor.fromInt(0xFFE6F0EA);

/// Rapport au format PDF (A4), montants complets.
Future<Uint8List> reportToPdf(Report r, ReportFonts fonts, {Uint8List? logo}) async {
  final doc = pw.Document(title: r.title, author: 'Nafa Élevage');
  final base = pw.TextStyle(font: fonts.regular, fontSize: 10);
  final bold = pw.TextStyle(font: fonts.bold, fontSize: 10);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    header: (c) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      if (logo != null) pw.Image(pw.MemoryImage(logo), height: 24) else pw.Text('Nafa Élevage', style: bold),
      pw.Text(r.title, style: base.copyWith(color: _muted, fontSize: 9)),
    ]),
    footer: (c) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Page ${c.pageNumber} sur ${c.pagesCount}', style: base.copyWith(color: _muted, fontSize: 8)),
    ),
    build: (c) => [
      pw.SizedBox(height: 12),
      pw.Text(r.title, style: bold.copyWith(fontSize: 18, color: _green)),
      pw.SizedBox(height: 2),
      pw.Text(r.subtitle, style: base.copyWith(color: _muted)),
      for (final s in r.sections) ...[
        pw.SizedBox(height: 14),
        pw.Text(s.title, style: bold.copyWith(fontSize: 12)),
        pw.SizedBox(height: 6),
        if (s.rows.isNotEmpty)
          pw.Table(
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
            children: [
              for (final (label, v) in s.rows)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Text(label, style: base)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(v.display, style: bold, textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
            ],
          ),
        if (s.table != null && s.table!.rows.isNotEmpty)
          pw.TableHelper.fromTextArray(
            headers: s.table!.headers,
            data: [
              for (final row in s.table!.rows) [for (final v in row) v.display],
              if (s.table!.totals != null) [for (final v in s.table!.totals!) v.display],
            ],
            headerStyle: bold.copyWith(fontSize: 8),
            cellStyle: base.copyWith(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: _light),
            cellAlignments: {
              for (var i = 1; i < s.table!.headers.length; i++) i: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
        if (s.table != null && s.table!.rows.isEmpty)
          pw.Text('Aucune donnée sur la période.', style: base.copyWith(color: _muted)),
        if (s.note != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(s.note!, style: base.copyWith(color: _muted, fontSize: 8)),
        ],
      ],
    ],
  ));
  return doc.save();
}

/// Rapport au format Excel : une feuille, nombres écrits comme nombres
/// (unités dans les en-têtes), pour pouvoir recalculer.
Uint8List reportToXlsx(Report r) {
  final book = xl.Excel.createExcel();
  const sheetName = 'Rapport';
  book.rename(book.getDefaultSheet()!, sheetName);
  final sheet = book[sheetName];
  final boldStyle = xl.CellStyle(bold: true);
  var row = 0;

  void put(int col, Object? v, {bool bold = false}) {
    final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = switch (v) {
      final RV rv when rv.number is int => xl.IntCellValue(rv.number! as int),
      final RV rv when rv.number != null => xl.DoubleCellValue(rv.number!.toDouble()),
      final RV rv => xl.TextCellValue(rv.display),
      final String s => xl.TextCellValue(s),
      _ => null,
    };
    if (bold) cell.cellStyle = boldStyle;
  }

  put(0, r.title, bold: true);
  row++;
  put(0, r.subtitle);
  row += 2;
  for (final s in r.sections) {
    put(0, s.title, bold: true);
    row++;
    for (final (label, v) in s.rows) {
      put(0, label);
      put(1, v);
      // Unité à côté des nombres, pour la lecture.
      put(2, switch (v.kind) { RVKind.money => 'FCFA', RVKind.pct => '%', RVKind.kg => 'kg', _ => null });
      row++;
    }
    final t = s.table;
    if (t != null) {
      for (var i = 0; i < t.headers.length; i++) {
        put(i, t.headers[i], bold: true);
      }
      row++;
      for (final line in [...t.rows, ?t.totals]) {
        for (var i = 0; i < line.length; i++) {
          put(i, line[i], bold: identical(line, t.totals));
        }
        row++;
      }
    }
    if (s.note != null) {
      put(0, s.note);
      row++;
    }
    row++;
  }
  sheet.setColumnWidth(0, 42);
  for (var i = 1; i < 9; i++) {
    sheet.setColumnWidth(i, 18);
  }
  return Uint8List.fromList(book.encode()!);
}
