import 'package:material_ui/material_ui.dart';

import '../domain/production.dart';

/// Icônes simples, toujours accompagnées d'un libellé.
IconData productionIcon(ProductionType p) {
  switch (p) {
    case ProductionType.chair:
      return Icons.scale_outlined;
    case ProductionType.ameliorees:
      return Icons.star_outline;
    case ProductionType.pondeuses:
      return Icons.egg_outlined;
    case ProductionType.couveuse:
      return Icons.thermostat_outlined;
  }
}

IconData moduleIcon(AppModule m) {
  switch (m) {
    case AppModule.tableauDeBord:
      return Icons.home_outlined;
    case AppModule.lots:
    case AppModule.lotsOeufs:
      return Icons.grid_view_outlined;
    case AppModule.alimentation:
      return Icons.grass_outlined;
    case AppModule.sante:
      return Icons.medical_services_outlined;
    case AppModule.ponteReforme:
    case AppModule.ponteOeufs:
      return Icons.egg_outlined;
    case AppModule.couvaison:
      return Icons.swap_horiz;
    case AppModule.calendrierCouvaison:
      return Icons.calendar_month_outlined;
    case AppModule.eclosions:
      return Icons.egg_alt_outlined;
    case AppModule.productionMensuelle:
      return Icons.bar_chart;
    case AppModule.poussinsGardes:
      return Icons.pets_outlined;
    case AppModule.ventes:
      return Icons.point_of_sale_outlined;
    case AppModule.depenses:
      return Icons.receipt_long_outlined;
    case AppModule.comptabilite:
      return Icons.account_balance_outlined;
    case AppModule.rapports:
      return Icons.description_outlined;
    case AppModule.parametres:
      return Icons.settings_outlined;
  }
}
