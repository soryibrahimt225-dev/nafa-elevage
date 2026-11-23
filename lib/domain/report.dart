import 'feed.dart';
import 'format.dart';

/// Valeur d'un rapport : affichée en français à l'écran et dans le PDF,
/// écrite comme nombre dans Excel.
class RV {
  const RV._(this.kind, this.value);
  const RV.text(String s) : this._(RVKind.text, s);
  const RV.integer(int n) : this._(RVKind.integer, n);
  const RV.money(int n) : this._(RVKind.money, n);
  const RV.pct(double? r) : this._(RVKind.pct, r);
  const RV.kg(int grams) : this._(RVKind.kg, grams);
  RV.date(DateTime d) : this._(RVKind.date, d);

  final RVKind kind;
  final Object? value;

  String get display => switch (kind) {
        RVKind.text => value! as String,
        RVKind.integer => formatInt(value! as int),
        RVKind.money => formatFcfa(value! as int),
        RVKind.pct => formatPercent(value as double?),
        RVKind.kg => formatKg(value! as int),
        RVKind.date => formatDate(value! as DateTime),
      };

  /// Valeur numérique pour Excel (null = texte).
  num? get number => switch (kind) {
        RVKind.integer || RVKind.money => value! as int,
        RVKind.pct => value == null ? null : ((value! as double) * 1000).round() / 10, // en %
        RVKind.kg => (value! as int) / 1000,
        _ => null,
      };

  @override
  String toString() => display;
}

enum RVKind { text, integer, money, pct, kg, date }

/// Tableau d'un rapport. Les en-têtes portent l'unité des colonnes
/// numériques (FCFA, %, kg) pour l'export Excel.
class ReportTable {
  ReportTable({required this.headers, required this.rows, this.totals});
  final List<String> headers;
  final List<List<RV>> rows;
  final List<RV>? totals;
}

class ReportSection {
  ReportSection(this.title, {this.rows = const [], this.table, this.note});
  final String title;
  final List<(String, RV)> rows;
  final ReportTable? table;
  final String? note;
}

class Report {
  Report({required this.title, required this.subtitle, required this.generatedAt, required this.sections});
  final String title;
  final String subtitle;
  final DateTime generatedAt;
  final List<ReportSection> sections;

  /// Nom de fichier sans accents ni espaces (ex. rapport-financier-2026-11).
  String fileName(String extension) {
    const from = 'àâäéèêëîïôöùûüçœ’ ';
    const to = 'aaaeeeeiioouuuco--';
    final b = StringBuffer();
    for (final ch in title.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      if (i >= 0) {
        b.write(to[i]);
      } else if (RegExp(r'[a-z0-9-]').hasMatch(ch)) {
        b.write(ch);
      }
    }
    final d = generatedAt;
    final name = b.toString().replaceAll(RegExp('-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return '$name-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.$extension';
  }
}
