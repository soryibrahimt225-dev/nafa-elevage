/// Productions gérées par Nafa Élevage et modules visibles pour chacune.
///
/// Règle validée : le menu n'affiche que les modules utiles à la production
/// choisie. La couveuse n'affiche jamais « Santé et vaccination ».
enum ProductionType {
  chair('Poulets de chair', 'Démarrage, finition et vente des sujets'),
  ameliorees('Races améliorées', 'Goliath, Kuroiler, SASSO, Bleu de Hollande, Wassachè…'),
  pondeuses('Pondeuses', 'Ponte, œufs, alimentation et réforme'),
  couveuse('Couveuse', 'Œufs, incubation, éclosion et poussins');

  const ProductionType(this.label, this.description);
  final String label;
  final String description;

  static ProductionType? fromName(String? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

enum AppModule {
  tableauDeBord('Tableau de bord'),
  lots('Lots et sujets'),
  lotsOeufs('Lots d’œufs'),
  alimentation('Alimentation'),
  sante('Santé et vaccination'),
  ponteReforme('Ponte, maintien et réforme'),
  ponteOeufs('Ponte et œufs'),
  couvaison('Couvaison et conversion'),
  calendrierCouvaison('Calendrier de couvaison'),
  eclosions('Éclosions'),
  productionMensuelle('Production mensuelle'),
  poussinsGardes('Poussins gardés'),
  ventes('Ventes'),
  depenses('Dépenses'),
  comptabilite('Comptabilité générale'),
  rapports('Rapports'),
  parametres('Paramètres');

  const AppModule(this.label);
  final String label;
}

/// Options que le producteur peut activer en plus de sa production.
enum OptionalFeature {
  /// Couvaison et conversion pour les races améliorées.
  couvaisonConversion,

  /// Couveuse optionnelle pour les pondeuses.
  couveusePondeuses,
}

/// Modules visibles, dans l'ordre du menu.
List<AppModule> modulesFor(ProductionType production,
    {Set<OptionalFeature> options = const {}}) {
  switch (production) {
    case ProductionType.chair:
      return const [
        AppModule.tableauDeBord,
        AppModule.lots,
        AppModule.alimentation,
        AppModule.sante,
        AppModule.ventes,
        AppModule.depenses,
        AppModule.comptabilite,
        AppModule.rapports,
        AppModule.parametres,
      ];
    case ProductionType.ameliorees:
      return [
        AppModule.tableauDeBord,
        AppModule.lots,
        AppModule.alimentation,
        AppModule.sante,
        AppModule.ponteReforme,
        if (options.contains(OptionalFeature.couvaisonConversion))
          AppModule.couvaison,
        AppModule.ventes,
        AppModule.depenses,
        AppModule.comptabilite,
        AppModule.rapports,
        AppModule.parametres,
      ];
    case ProductionType.pondeuses:
      return [
        AppModule.tableauDeBord,
        AppModule.lots,
        AppModule.alimentation,
        AppModule.sante,
        AppModule.ponteOeufs,
        if (options.contains(OptionalFeature.couveusePondeuses))
          AppModule.couvaison,
        AppModule.ventes,
        AppModule.depenses,
        AppModule.comptabilite,
        AppModule.rapports,
        AppModule.parametres,
      ];
    case ProductionType.couveuse:
      return const [
        AppModule.tableauDeBord,
        AppModule.lotsOeufs,
        AppModule.calendrierCouvaison,
        AppModule.eclosions,
        AppModule.productionMensuelle,
        AppModule.poussinsGardes,
        AppModule.ventes,
        AppModule.depenses,
        AppModule.comptabilite,
        AppModule.rapports,
        AppModule.parametres,
      ];
  }
}

/// Options proposées pour une production (affichées à l'onboarding).
List<OptionalFeature> optionsFor(ProductionType production) {
  switch (production) {
    case ProductionType.ameliorees:
      return const [OptionalFeature.couvaisonConversion];
    case ProductionType.pondeuses:
      return const [OptionalFeature.couveusePondeuses];
    case ProductionType.chair:
    case ProductionType.couveuse:
      return const [];
  }
}

String optionLabel(OptionalFeature f) {
  switch (f) {
    case OptionalFeature.couvaisonConversion:
      return 'Activer la couvaison et la conversion';
    case OptionalFeature.couveusePondeuses:
      return 'Activer la couveuse';
  }
}

String optionHelp(OptionalFeature f) {
  switch (f) {
    case OptionalFeature.couvaisonConversion:
      return 'Œufs fertiles, passage de sujets vers la ponte, poussins issus de vos propres œufs.';
    case OptionalFeature.couveusePondeuses:
      return 'Mettre une partie de vos œufs en couveuse pour produire vos poussins.';
  }
}
