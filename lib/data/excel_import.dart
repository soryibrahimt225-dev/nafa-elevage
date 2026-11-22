import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../domain/incubation.dart';
import '../domain/lots.dart';

/// Résultat d'un import : lots lus, et lignes ignorées avec la raison.
class ImportResult {
  ImportResult(this.lots, this.warnings);
  final List<IncubationLot> lots;
  final List<String> warnings;
}

/// Lit l'onglet « Lots » du classeur Gestion-couvoir (en-têtes en ligne 4,
/// données à partir de la ligne 5). Seules les colonnes saisies à la main sont
/// reprises : tout le reste (dates, statut, taux) est recalculé par Nafa.
ImportResult importCouvoirWorkbook(Uint8List bytes, {Iterable<String> existingCodes = const []}) {
  final Excel book;
  try {
    book = Excel.decodeBytes(bytes);
  } catch (_) {
    return ImportResult(const [], ['Le fichier n’est pas un classeur Excel lisible (.xlsx).']);
  }
  final sheet = book.tables['Lots'];
  if (sheet == null) {
    return ImportResult(const [], ['Onglet « Lots » introuvable dans le classeur.']);
  }
  final rows = <List<Object?>>[
    for (var r = 4; r < sheet.maxRows; r++)
      [for (final c in sheet.row(r).take(19)) _plain(c?.value)],
  ];
  return importLotRows(rows, existingCodes: existingCodes);
}

Object? _plain(CellValue? v) {
  switch (v) {
    case null:
      return null;
    case IntCellValue():
      return v.value;
    case DoubleCellValue():
      return v.value;
    case TextCellValue():
      return v.value.toString();
    case DateCellValue():
      return DateTime(v.year, v.month, v.day);
    case DateTimeCellValue():
      return DateTime(v.year, v.month, v.day);
    case FormulaCellValue():
      // La bibliothèque ne donne pas toujours la valeur calculée : on reprend
      // un code de lot, ou une addition saisie à la main (ex. « =88+9 »).
      final s = v.formula.trim();
      if (RegExp(r'^(BUR|CLI)-\d{2}-\d{3}$').hasMatch(s)) return s;
      return evalSimpleSum(s);
    default:
      return v.toString();
  }
}

/// Colonnes : A code, B date d'entrée, C type, D propriétaire, E durée,
/// F œufs mis, J œufs éclos, M mortalité poussins, S observations.
ImportResult importLotRows(List<List<Object?>> rows, {Iterable<String> existingCodes = const []}) {
  final lots = <IncubationLot>[];
  final warnings = <String>[];
  final known = {...existingCodes};
  var n = 0;

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final line = i + 5;
    Object? col(int c) => c < row.length ? row[c] : null;

    final date = col(1);
    final type = col(2);
    if (date == null && type == null) continue; // ligne vide ou total
    if (date is! DateTime) {
      if (col(0) == 'TOTAL / MOYENNE' || (col(0)?.toString().startsWith('TOTAL') ?? false)) continue;
      warnings.add('Ligne $line ignorée : date d’entrée absente ou illisible.');
      continue;
    }
    final ownerType = switch (type?.toString().trim().toLowerCase()) {
      'bureau' => OwnerType.producteur,
      'client' => OwnerType.client,
      _ => null,
    };
    if (ownerType == null) {
      warnings.add('Ligne $line ignorée : type « $type » inconnu (Bureau ou Client attendu).');
      continue;
    }
    final days = _int(col(4));
    final eggs = _int(col(5));
    if (days == null || eggs == null) {
      warnings.add('Ligne $line ignorée : durée ou nombre d’œufs manquant.');
      continue;
    }
    final profile = days == 28
        ? defaultSpeciesProfiles.firstWhere((p) => p.id == 'pintade')
        : days == 21
            ? defaultSpeciesProfiles.firstWhere((p) => p.id == 'goliath')
            : null;
    final descente = profile?.descenteDay ?? (days - 5);
    final code = (col(0) as String?) ?? nextLotCode(ownerType.prefix, date, known);
    if (known.contains(code)) {
      warnings.add('Ligne $line ignorée : le lot $code existe déjà.');
      continue;
    }
    try {
      final lot = IncubationLot(
        id: 'import-$code',
        code: code,
        ownerType: ownerType,
        ownerName: col(3)?.toString().trim() ?? ownerType.label,
        speciesLabel: profile?.label ?? 'Espèce à préciser',
        entryDate: date,
        eggsSet: eggs,
        incubationDays: days,
        descenteDay: descente,
        hatched: _int(col(9)),
        chickDeaths: _int(col(12)),
        observations: col(18)?.toString().trim() ?? '',
      );
      lots.add(lot);
      known.add(code);
      n++;
    } on ArgumentError catch (e) {
      warnings.add('Ligne $line ($code) ignorée : ${e.message}');
    }
  }
  if (n == 0 && warnings.isEmpty) warnings.add('Aucun lot trouvé dans l’onglet « Lots ».');
  return ImportResult(lots, warnings);
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is double && v == v.roundToDouble()) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// Évalue une somme simple d'entiers (« 88+9 », « =87 + 20 - 1 »). `null` sinon.
int? evalSimpleSum(String formula) {
  final f = formula.replaceAll(' ', '').replaceFirst(RegExp(r'^='), '');
  if (!RegExp(r'^\d+([+-]\d+)*$').hasMatch(f)) return null;
  var total = 0;
  for (final m in RegExp(r'([+-]?)(\d+)').allMatches(f)) {
    final n = int.parse(m.group(2)!);
    total += m.group(1) == '-' ? -n : n;
  }
  return total;
}
