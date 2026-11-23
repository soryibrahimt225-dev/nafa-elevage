import 'format.dart';

/// Ramassage d'œufs d'un lot pour une journée.
/// Œufs de table = ramassés − cassés − mis de côté comme œufs fertiles.
class EggRecord {
  EggRecord({
    required this.lotCode,
    required DateTime date,
    required this.collected,
    this.broken = 0,
    this.fertile = 0,
    this.note = '',
  }) : date = DateTime(date.year, date.month, date.day) {
    if (collected < 0 || broken < 0 || fertile < 0) throw ArgumentError('Les nombres ne peuvent pas être négatifs.');
    if (broken + fertile > collected) {
      throw ArgumentError('Cassés + fertiles (${formatInt(broken + fertile)}) dépassent les œufs ramassés (${formatInt(collected)}).');
    }
  }

  final String lotCode;
  final DateTime date;
  final int collected;
  final int broken;
  final int fertile;
  final String note;

  int get table => collected - broken - fertile;

  Map<String, Object?> toJson() => {
        'lotCode': lotCode,
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'collected': collected,
        'broken': broken,
        'fertile': fertile,
        'note': note,
      };

  factory EggRecord.fromJson(Map<String, Object?> j) => EggRecord(
        lotCode: j['lotCode']! as String,
        date: DateTime.parse(j['date']! as String),
        collected: j['collected']! as int,
        broken: (j['broken'] as int?) ?? 0,
        fertile: (j['fertile'] as int?) ?? 0,
        note: (j['note'] as String?) ?? '',
      );
}

/// Taux de ponte d'une journée : œufs ramassés / sujets présents.
double? layingRate(int collected, int hens) => hens <= 0 ? null : collected / hens;

/// Synthèse de ponte sur une liste de ramassages.
class EggSummary {
  EggSummary(Iterable<EggRecord> records) {
    for (final r in records) {
      days.add(r.date);
      collected += r.collected;
      broken += r.broken;
      fertile += r.fertile;
    }
  }

  final Set<DateTime> days = {};
  int collected = 0, broken = 0, fertile = 0;
  int get table => collected - broken - fertile;
  double? get brokenRate => collected == 0 ? null : broken / collected;
}
