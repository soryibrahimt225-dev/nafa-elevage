import 'feed.dart';
import 'lots.dart';

/// Pesée d'un lot : poids moyen d'un échantillon de sujets.
class Weighing {
  Weighing({
    required this.id,
    required this.lotCode,
    required DateTime date,
    required this.averageGrams,
    this.sampleSize = 0,
    this.note = '',
  }) : date = DateTime(date.year, date.month, date.day) {
    if (averageGrams <= 0) throw ArgumentError('Le poids moyen doit être supérieur à 0.');
    if (averageGrams > 20000) throw ArgumentError('Poids moyen trop élevé : vérifiez l’unité (grammes).');
    if (sampleSize < 0) throw ArgumentError('Nombre de sujets pesés invalide.');
  }

  final String id;
  final String lotCode;
  final DateTime date;

  /// Poids moyen d'un sujet (g).
  final int averageGrams;

  /// Nombre de sujets pesés (0 = non précisé).
  final int sampleSize;
  final String note;

  Map<String, Object?> toJson() => {
        'id': id,
        'lotCode': lotCode,
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'averageGrams': averageGrams,
        'sampleSize': sampleSize,
        'note': note,
      };

  factory Weighing.fromJson(Map<String, Object?> j) => Weighing(
        id: j['id']! as String,
        lotCode: j['lotCode']! as String,
        date: DateTime.parse(j['date']! as String),
        averageGrams: j['averageGrams']! as int,
        sampleSize: (j['sampleSize'] as int?) ?? 0,
        note: (j['note'] as String?) ?? '',
      );
}

/// Croissance d'un lot entre sa première et sa dernière pesée.
///
/// Indice de consommation (IC) = aliment distribué entre les deux pesées
/// ÷ (gain de poids moyen × sujets présents à la dernière pesée).
/// Pour compter depuis le démarrage, enregistrer une pesée le jour du
/// démarrage (ex. 40 g pour un poussin d'un jour).
class Growth {
  Growth(this.lot, Iterable<Weighing> weighings, Iterable<FeedMove> moves)
      : weighings = (weighings.where((w) => w.lotCode == lot.code).toList()..sort((a, b) => a.date.compareTo(b.date))) {
    if (this.weighings.length >= 2) {
      final from = first!.date, to = last!.date;
      feedGrams = moves
          .where((m) =>
              m.type == FeedMoveType.distribution && m.lotCode == lot.code && m.date.isAfter(from) && !m.date.isAfter(to))
          .fold(0, (s, m) => s + m.grams);
    }
  }

  final AnimalLot lot;
  final List<Weighing> weighings;
  int feedGrams = 0;

  Weighing? get first => weighings.isEmpty ? null : weighings.first;
  Weighing? get last => weighings.isEmpty ? null : weighings.last;
  bool get hasTwo => weighings.length >= 2;

  int get days => hasTwo ? last!.date.difference(first!.date).inDays : 0;

  /// Gain de poids moyen par sujet (g).
  int? get gainPerSubject => hasTwo ? last!.averageGrams - first!.averageGrams : null;

  /// Gain moyen quotidien (g par sujet et par jour).
  double? get dailyGain => !hasTwo || days == 0 ? null : gainPerSubject! / days;

  /// Gain de poids total du lot (g).
  int? get totalGain => hasTwo ? gainPerSubject! * lot.countAt(last!.date) : null;

  /// Indice de consommation ; `null` sans aliment ou sans gain.
  double? get fcr {
    final g = totalGain;
    if (g == null || g <= 0 || feedGrams <= 0) return null;
    return feedGrams / g;
  }

  /// Poids estimé du lot à la dernière pesée (g).
  int? get flockWeight => last == null ? null : last!.averageGrams * lot.countAt(last!.date);
}

/// 1 720 g → « 1,72 kg » ; 850 g → « 850 g ».
String formatWeight(int grams) {
  if (grams < 1000) return '$grams g';
  final kg = (grams / 1000).toStringAsFixed(2).replaceAll('.', ',');
  return '$kg kg';
}

/// 1.784 → « 1,78 ».
String formatFcr(double? v) => v == null ? '—' : v.toStringAsFixed(2).replaceAll('.', ',');
