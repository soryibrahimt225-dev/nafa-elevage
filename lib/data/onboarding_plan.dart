import '../domain/farm.dart';
import '../domain/feed.dart';
import '../domain/finance.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import 'app_data.dart';

/// Premier lot décrit pendant l'assistant.
class FirstLot {
  const FirstLot({required this.startDate, required this.count, this.objectives = const {}});
  final DateTime startDate;
  final int count;
  /// Objectifs menés ensemble (races améliorées).
  final Set<LotObjective> objectives;
}

/// Aliment et stock de départ décrits pendant l'assistant.
class FirstFeed {
  const FirstFeed({required this.name, required this.stage, this.kgPerBag = 50, this.bags = 0, this.pricePerBag = 0});
  final String name;
  final FeedStage stage;
  final int kgPerBag;
  final int bags;
  final int pricePerBag;
}

/// Réponses de l'assistant de démarrage (dossier, section 4). Rien n'est
/// enregistré avant [apply] : on peut revenir en arrière sans rien créer.
class OnboardingPlan {
  String farmName = '';
  String location = '';
  ProductionType? production;
  Set<OptionalFeature> options = {};

  /// Race (chair, races améliorées, pondeuses) ou espèce principale
  /// (couveuse, identifiant d'espèce).
  String? breed;
  FirstLot? lot;

  /// Aliments de départ : un par stade, chacun avec son prix.
  final List<FirstFeed> feeds = [];
  final Map<SaleCategory, int> prices = {};

  /// Prix par type vendu (ex. sujets : « Sujet de 6 mois » → 7 500).
  final Map<SaleCategory, Map<String, int?>> variantPrices = {};

  /// Œufs par alvéole (vente des œufs de table).
  int? eggsPerTray;
  final List<FarmUser> users = [];

  /// Aliment proposé selon la production.
  static FeedStage suggestedStage(ProductionType p) =>
      p == ProductionType.pondeuses ? FeedStage.pondeuse : FeedStage.demarrage;

  /// Enregistre tout. Renvoie le code du premier lot créé, s'il y en a un.
  Future<String?> apply(AppData data, DateTime today) async {
    final p = production;
    if (p == null) throw ArgumentError('Choisissez une production.');
    await data.settings.setFarm(FarmProfile(name: farmName.trim(), location: location.trim(), users: users));

    for (final e in prices.entries) {
      await data.config.setPrice(e.key, e.value);
    }
    for (final e in variantPrices.entries) {
      await data.config.setVariants(e.key, e.value);
    }
    if (eggsPerTray != null) await data.config.setEggsPerTray(eggsPerTray!);

    final b = breed?.trim();
    if (b != null && b.isNotEmpty) {
      if (p == ProductionType.couveuse) {
        await data.config.setDefaultSpecies(b);
      } else if (!data.config.breedsFor(p).any((x) => x.toLowerCase() == b.toLowerCase())) {
        await data.config.addBreed(p, b);
      }
    }

    String? code;
    final l = lot;
    if (l != null && p != ProductionType.couveuse) {
      if (b == null || b.isEmpty) throw ArgumentError('Indiquez la race du premier lot.');
      code = data.lots.nextAnimalCode(p, l.startDate);
      await data.lots.addAnimalLot(AnimalLot(
        id: data.lots.newId(),
        code: code,
        production: p,
        breed: b,
        startDate: l.startDate,
        initialCount: l.count,
        objectives: p == ProductionType.ameliorees ? {...l.objectives} : {},
      ));
    }

    for (final f in feeds.where((f) => f.name.trim().isNotEmpty)) {
      final item = FeedItem(
          id: data.feed.newId(),
          name: f.name.trim(),
          stage: f.stage,
          kgPerBag: f.kgPerBag,
          bagPrice: f.pricePerBag > 0 ? f.pricePerBag : null);
      await data.feed.saveItem(item);
      if (f.bags > 0) {
        // Stock déjà présent : pas de dépense créée (achat antérieur).
        await data.feed.addMove(FeedMove(
          id: data.feed.newId(),
          itemId: item.id,
          date: today,
          type: FeedMoveType.achat,
          grams: f.bags * f.kgPerBag * 1000,
          cost: f.bags * f.pricePerBag,
          note: 'Stock de départ',
        ));
      }
    }

    // En dernier : l'application passe alors au tableau de bord.
    await data.settings.choose(p, options);
    return code;
  }
}
