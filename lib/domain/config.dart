import 'finance.dart';
import 'incubation.dart';
import 'production.dart';
import 'reminders.dart';

/// Cycle d'une race améliorée. Valeurs par défaut du cahier des charges,
/// modifiables par race. Ce sont des repères de contrôle : la réforme n'est
/// jamais automatique, elle reste une décision du producteur.
class ImprovedCycle {
  const ImprovedCycle({
    this.selectionMonths = 4,
    this.layingStartMonths = 6,
    this.productionReviewMonths = 12,
    this.reformReviewMonths = 24,
  });

  final int selectionMonths;
  final int layingStartMonths;
  final int productionReviewMonths;
  final int reformReviewMonths;

  static void validate(int sel, int lay, int prod, int reform) {
    if (sel <= 0) throw ArgumentError('L’âge de sélection doit être supérieur à 0.');
    if (!(sel <= lay && lay <= prod && prod <= reform)) {
      throw ArgumentError('Les âges doivent se suivre : sélection ≤ entrée en ponte ≤ contrôle de production ≤ contrôle de réforme.');
    }
  }

  /// Étapes datées à partir de la date de démarrage du lot.
  List<(String, DateTime)> milestones(DateTime start) => [
        ('Sélection pour la ponte', addMonths(start, selectionMonths)),
        ('Entrée en ponte', addMonths(start, layingStartMonths)),
        ('Contrôle de production', addMonths(start, productionReviewMonths)),
        ('Contrôle de réforme', addMonths(start, reformReviewMonths)),
      ];

  Map<String, Object?> toJson() => {
        'selectionMonths': selectionMonths,
        'layingStartMonths': layingStartMonths,
        'productionReviewMonths': productionReviewMonths,
        'reformReviewMonths': reformReviewMonths,
      };

  factory ImprovedCycle.fromJson(Map<String, Object?> j) => ImprovedCycle(
        selectionMonths: j['selectionMonths']! as int,
        layingStartMonths: j['layingStartMonths']! as int,
        productionReviewMonths: j['productionReviewMonths']! as int,
        reformReviewMonths: j['reformReviewMonths']! as int,
      );
}

/// Ajoute des mois en restant sur un jour valide (31 janvier + 1 mois →
/// 28 ou 29 février).
DateTime addMonths(DateTime d, int months) {
  final y = d.year + ((d.month - 1 + months) ~/ 12);
  final m = (d.month - 1 + months) % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > lastDay ? lastDay : d.day);
}

/// Races proposées par défaut (le producteur peut en ajouter ou en retirer).
const defaultBreeds = <ProductionType, List<String>>{
  ProductionType.chair: ['Cobb 500', 'Ross 308', 'Poulet de chair local'],
  ProductionType.ameliorees: ['Goliath', 'Kuroiler', 'SASSO', 'Bleu de Hollande', 'Wassachè'],
  ProductionType.pondeuses: ['ISA Brown', 'Bovans Brown', 'Hisex', 'Dekalb', 'Shaver', 'Babcock'],
};

SpeciesProfile speciesFromJson(Map<String, Object?> j) => SpeciesProfile(
      id: j['id']! as String,
      label: j['label']! as String,
      incubationDays: j['incubationDays']! as int,
      descenteDay: j['descenteDay']! as int,
    );

Map<String, Object?> speciesToJson(SpeciesProfile p) =>
    {'id': p.id, 'label': p.label, 'incubationDays': p.incubationDays, 'descenteDay': p.descenteDay};

/// Paramètres de l'exploitation (valeurs dépendant de la race ou de la
/// pratique du producteur).
class FarmConfig {
  FarmConfig({
    List<SpeciesProfile>? species,
    Map<ProductionType, List<String>>? breeds,
    Map<SaleCategory, int>? prices,
    Map<String, ImprovedCycle>? cycles,
    this.reminders = const ReminderPrefs(),
    this.eggsPerTray = 30,
    Map<SaleCategory, Map<String, int?>>? variants,
  })  : variants = variants ?? {},
        species = species ?? [...defaultSpeciesProfiles],
        breeds = breeds ?? {for (final e in defaultBreeds.entries) e.key: [...e.value]},
        prices = prices ?? {},
        cycles = cycles ?? {};

  final List<SpeciesProfile> species;
  final Map<ProductionType, List<String>> breeds;

  /// Prix de référence par catégorie de vente (repère, modifiable à la vente).
  final Map<SaleCategory, int> prices;

  /// Cycle par race améliorée ; une race absente utilise le cycle par défaut.
  final Map<String, ImprovedCycle> cycles;

  /// Réglages des rappels de couvaison.
  ReminderPrefs reminders;

  /// Nombre d'œufs dans une alvéole (vente des œufs de table).
  int eggsPerTray;

  /// Types vendus et leur prix, par catégorie (ex. sujets : « Sujet de
  /// 6 mois » → 7 500 FCFA). Absent = types par défaut de la production.
  final Map<SaleCategory, Map<String, int?>> variants;

  ImprovedCycle cycleFor(String breed) => cycles[breed] ?? const ImprovedCycle();

  SpeciesProfile? speciesById(String id) {
    for (final s in species) {
      if (s.id == id) return s;
    }
    return null;
  }

  void setSpecies(SpeciesProfile p) {
    IncubationSchedule(entryDate: DateTime(2026), incubationDays: p.incubationDays, descenteDay: p.descenteDay);
    if (p.label.trim().isEmpty) throw ArgumentError('Indiquez le nom de l’espèce.');
    final i = species.indexWhere((s) => s.id == p.id);
    if (i >= 0) {
      species[i] = p;
    } else {
      if (species.any((s) => s.label.toLowerCase() == p.label.trim().toLowerCase())) {
        throw ArgumentError('Cette espèce existe déjà.');
      }
      species.add(p);
    }
  }

  void addBreed(ProductionType p, String breed) {
    final b = breed.trim();
    if (b.isEmpty) throw ArgumentError('Indiquez le nom de la race.');
    final list = breeds.putIfAbsent(p, () => []);
    if (list.any((x) => x.toLowerCase() == b.toLowerCase())) throw ArgumentError('Cette race existe déjà.');
    list.add(b);
  }

  Map<String, Object?> toJson() => {
        'species': [for (final s in species) speciesToJson(s)],
        'breeds': {for (final e in breeds.entries) e.key.name: e.value},
        'prices': {for (final e in prices.entries) e.key.name: e.value},
        'cycles': {for (final e in cycles.entries) e.key: e.value.toJson()},
        'reminders': reminders.toJson(),
        'eggsPerTray': eggsPerTray,
        'variants': {for (final e in variants.entries) e.key.name: e.value},
      };

  factory FarmConfig.fromJson(Map<String, Object?> j) => FarmConfig(
        species: [for (final s in (j['species'] as List)) speciesFromJson((s as Map).cast())],
        breeds: {
          for (final e in (j['breeds'] as Map).entries)
            ProductionType.values.byName(e.key as String): (e.value as List).cast<String>().toList(),
        },
        prices: {
          for (final e in ((j['prices'] as Map?) ?? const {}).entries)
            SaleCategory.values.byName(e.key as String): e.value as int,
        },
        cycles: {
          for (final e in ((j['cycles'] as Map?) ?? const {}).entries)
            e.key as String: ImprovedCycle.fromJson((e.value as Map).cast()),
        },
        eggsPerTray: (j['eggsPerTray'] as int?) ?? 30,
        variants: {
          for (final e in ((j['variants'] as Map?) ?? const {}).entries)
            SaleCategory.values.byName(e.key as String): (e.value as Map).map((k, v) => MapEntry(k as String, v as int?)),
        },
        reminders: j['reminders'] == null
            ? const ReminderPrefs()
            : ReminderPrefs.fromJson((j['reminders'] as Map).cast()),
      );
}
