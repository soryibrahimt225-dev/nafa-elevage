import 'format.dart';

/// Stade d'alimentation (intitulés validés : démarrage, poulette, finition,
/// pondeuse). Les âges de chaque phase restent au choix du producteur.
enum FeedStage {
  demarrage('Démarrage'),
  croissance('Croissance'),
  poulette('Poulette'),
  finition('Finition'),
  pondeuse('Pondeuse'),
  reproduction('Reproduction'),
  autre('Autre (matière première, complément)');

  const FeedStage(this.label);
  final String label;
}

/// Aliment du catalogue. Le stock est suivi en grammes (nombres entiers,
/// pas d'erreur d'arrondi) et affiché en kilogrammes.
class FeedItem {
  FeedItem({
    required this.id,
    required this.name,
    required this.stage,
    this.kgPerBag = 50,
    this.alertKg,
    this.supplier = '',
    this.bagPrice,
  }) {
    if (name.trim().isEmpty) throw ArgumentError('Indiquez le nom de l’aliment.');
    if (kgPerBag <= 0) throw ArgumentError('Le poids du sac doit être supérieur à 0.');
    if (alertKg != null && alertKg! < 0) throw ArgumentError('Le seuil d’alerte ne peut pas être négatif.');
    if (bagPrice != null && bagPrice! < 0) throw ArgumentError('Le prix ne peut pas être négatif.');
  }

  final String id;
  final String name;
  final FeedStage stage;

  /// Poids d'un sac (kg) : les achats se saisissent en sacs.
  final int kgPerBag;

  /// Alerte quand le stock passe sous ce seuil (kg).
  final int? alertKg;
  final String supplier;

  /// Prix habituel d'un sac (FCFA), proposé à chaque achat : chaque aliment
  /// (démarrage, croissance, finition, pondeuse…) a son propre prix.
  final int? bagPrice;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'stage': stage.name,
        'kgPerBag': kgPerBag,
        'alertKg': alertKg,
        'supplier': supplier,
        if (bagPrice != null) 'bagPrice': bagPrice,
      };

  factory FeedItem.fromJson(Map<String, Object?> j) => FeedItem(
        id: j['id']! as String,
        name: j['name']! as String,
        stage: FeedStage.values.byName(j['stage']! as String),
        kgPerBag: (j['kgPerBag'] as int?) ?? 50,
        alertKg: j['alertKg'] as int?,
        supplier: (j['supplier'] as String?) ?? '',
        bagPrice: j['bagPrice'] as int?,
      );
}

/// Aliments proposés selon la production (un par stade, chacun son prix).
List<FeedStage> defaultFeedStages(String production) => switch (production) {
      'chair' => const [FeedStage.demarrage, FeedStage.croissance, FeedStage.finition],
      'pondeuses' => const [FeedStage.demarrage, FeedStage.poulette, FeedStage.pondeuse],
      'ameliorees' => const [FeedStage.demarrage, FeedStage.croissance, FeedStage.finition, FeedStage.pondeuse],
      _ => const [],
    };

enum FeedMoveType {
  achat('Achat'),
  distribution('Distribution'),
  perte('Perte');

  const FeedMoveType(this.label);
  final String label;
}

/// Mouvement de stock d'un aliment.
class FeedMove {
  FeedMove({
    required this.id,
    required this.itemId,
    required DateTime date,
    required this.type,
    required this.grams,
    this.cost = 0,
    this.lotCode,
    this.note = '',
    this.expenseId,
  }) : date = DateTime(date.year, date.month, date.day) {
    if (grams <= 0) throw ArgumentError('La quantité doit être supérieure à 0.');
    if (cost < 0) throw ArgumentError('Le prix ne peut pas être négatif.');
    if (type == FeedMoveType.distribution && (lotCode == null || lotCode!.isEmpty)) {
      throw ArgumentError('Choisissez le lot qui reçoit l’aliment.');
    }
  }

  final String id;
  final String itemId;
  final DateTime date;
  final FeedMoveType type;
  final int grams;

  /// Prix total payé (achats seulement), en FCFA.
  final int cost;
  final String? lotCode;
  final String note;

  /// Dépense créée en même temps que l'achat (pour la supprimer avec lui).
  final String? expenseId;

  Map<String, Object?> toJson() => {
        'id': id,
        'itemId': itemId,
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'type': type.name,
        'grams': grams,
        'cost': cost,
        'lotCode': lotCode,
        'note': note,
        'expenseId': expenseId,
      };

  factory FeedMove.fromJson(Map<String, Object?> j) => FeedMove(
        id: j['id']! as String,
        itemId: j['itemId']! as String,
        date: DateTime.parse(j['date']! as String),
        type: FeedMoveType.values.byName(j['type']! as String),
        grams: j['grams']! as int,
        cost: (j['cost'] as int?) ?? 0,
        lotCode: j['lotCode'] as String?,
        note: (j['note'] as String?) ?? '',
        expenseId: j['expenseId'] as String?,
      );
}

/// État du stock d'un aliment.
class FeedStock {
  FeedStock(this.item, Iterable<FeedMove> moves) {
    for (final m in moves.where((m) => m.itemId == item.id)) {
      switch (m.type) {
        case FeedMoveType.achat:
          inGrams += m.grams;
          purchaseCost += m.cost;
        case FeedMoveType.distribution:
          distributedGrams += m.grams;
        case FeedMoveType.perte:
          lostGrams += m.grams;
      }
    }
  }

  final FeedItem item;
  int inGrams = 0, distributedGrams = 0, lostGrams = 0, purchaseCost = 0;

  int get remainingGrams => inGrams - distributedGrams - lostGrams;

  /// Coût moyen d'un kilogramme acheté (FCFA), `null` sans achat.
  double? get costPerKg => inGrams == 0 ? null : purchaseCost / (inGrams / 1000);

  /// Valeur du stock restant au coût moyen.
  int get value => costPerKg == null ? 0 : (remainingGrams / 1000 * costPerKg!).round();

  bool get low => item.alertKg != null && remainingGrams < item.alertKg! * 1000;
}

/// Consommation et coût alimentaire d'un lot (toutes les distributions,
/// valorisées au coût moyen de chaque aliment).
class LotFeed {
  LotFeed(String lotCode, Iterable<FeedMove> moves, Map<String, FeedStock> stocks) {
    for (final m in moves.where((m) => m.type == FeedMoveType.distribution && m.lotCode == lotCode)) {
      grams += m.grams;
      if (firstDate == null || m.date.isBefore(firstDate!)) firstDate = m.date;
      final c = stocks[m.itemId]?.costPerKg;
      if (c == null) {
        unpricedGrams += m.grams;
      } else {
        cost += m.grams / 1000 * c;
      }
    }
  }

  int grams = 0;

  /// Première distribution enregistrée pour le lot.
  DateTime? firstDate;

  /// Quantité distribuée sans prix d'achat connu (coût incomplet).
  int unpricedGrams = 0;
  double cost = 0;

  int get costFcfa => cost.round();

  /// Consommation moyenne par sujet et par jour (g), sur [days] jours
  /// avec [subjects] sujets en moyenne.
  double? gramsPerSubjectPerDay({required int subjects, required int days}) =>
      subjects <= 0 || days <= 0 ? null : grams / subjects / days;
}

/// Ration du jour : effectif × grammes par sujet (formule du dossier).
int rationGrams(int subjects, int gramsPerSubject) => subjects * gramsPerSubject;

/// 12 500 g → « 12,5 kg » ; 3 000 000 g → « 3 000 kg ».
String formatKg(int grams) {
  final whole = grams ~/ 1000;
  final tenth = ((grams % 1000) / 100).round();
  final w = tenth == 10 ? whole + 1 : whole;
  final t = tenth == 10 ? 0 : tenth;
  return t == 0 ? '${formatInt(w)} kg' : '${formatInt(w)},$t kg';
}

/// Conversion d'une saisie « 12,5 » ou « 12.5 » (kg) en grammes.
int? parseKg(String text) {
  final v = double.tryParse(text.trim().replaceAll(',', '.').replaceAll(' ', ''));
  if (v == null || v.isNaN || v.isInfinite) return null;
  return (v * 1000).round();
}
