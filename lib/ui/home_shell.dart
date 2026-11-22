import 'package:material_ui/material_ui.dart';

import '../data/app_data.dart';
import '../domain/production.dart';
import 'animal_lots_screen.dart';
import 'dashboard_screen.dart';
import 'finance_screens.dart';
import 'health_screen.dart';
import 'icons.dart';
import 'incubation_lots_screen.dart';
import 'monthly_production_screen.dart';
import 'incubation_calculator.dart';
import 'settings_screen.dart';
import 'theme.dart';

/// Structure principale : menu dynamique selon la production choisie.
/// Écran large : menu latéral fixe. Téléphone : menu dans un tiroir.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.data, this.today});
  final AppData data;
  final DateTime? today;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppModule _current = AppModule.tableauDeBord;

  void _go(AppModule m) => setState(() => _current = m);

  @override
  Widget build(BuildContext context) {
    final modules = widget.data.settings.modules;
    if (!modules.contains(_current)) _current = AppModule.tableauDeBord;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final production = widget.data.settings.production!;

    final menu = _ModuleMenu(
      production: production,
      modules: modules,
      current: _current,
      onSelect: (m) {
        _go(m);
        if (!wide) Navigator.of(context).maybePop();
      },
    );

    final body = _ModulePage(
      module: _current,
      data: widget.data,
      today: widget.today ?? DateTime.now(),
    );

    if (wide) {
      return Scaffold(
        body: Row(children: [
          SizedBox(width: 260, child: Material(color: NafaColors.surface, child: menu)),
          const VerticalDivider(width: 1, color: NafaColors.border),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_current.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      drawer: Drawer(backgroundColor: NafaColors.surface, child: menu),
      body: body,
    );
  }
}

class _ModuleMenu extends StatelessWidget {
  const _ModuleMenu({
    required this.production,
    required this.modules,
    required this.current,
    required this.onSelect,
  });
  final ProductionType production;
  final List<AppModule> modules;
  final AppModule current;
  final ValueChanged<AppModule> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Image.asset('assets/images/nafa_logo.png',
                height: 40, alignment: Alignment.centerLeft, semanticLabel: 'Nafa Élevage'),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NafaColors.greenLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PRODUCTION', style: TextStyle(fontSize: 11, color: NafaColors.textMuted, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(production.label,
                  key: const ValueKey('production-active'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),
          for (final m in modules)
            ListTile(
              key: ValueKey('menu-${m.name}'),
              leading: Icon(moduleIcon(m)),
              title: Text(m.label),
              selected: m == current,
              selectedColor: NafaColors.green,
              selectedTileColor: NafaColors.greenLight,
              dense: true,
              onTap: () => onSelect(m),
            ),
        ],
      ),
    );
  }
}

class _ModulePage extends StatelessWidget {
  const _ModulePage({required this.module, required this.data, required this.today});
  final AppModule module;
  final AppData data;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final settings = data.settings, lots = data.lots, finance = data.finance;
    final ctx = FinanceContext(
        finance: finance, lots: lots, production: settings.production!, options: settings.options, today: today);
    switch (module) {
      case AppModule.tableauDeBord:
        return DashboardScreen(
            store: lots, finance: finance, health: data.health, production: settings.production!, options: settings.options, today: today);
      case AppModule.sante:
        return HealthScreen(health: data.health, lots: lots, production: settings.production!, today: today);
      case AppModule.productionMensuelle:
        return MonthlyProductionScreen(store: lots);
      case AppModule.ventes:
        return SalesScreen(ctx: ctx);
      case AppModule.depenses:
        return ExpensesScreen(ctx: ctx);
      case AppModule.comptabilite:
        return AccountingScreen(ctx: ctx);
      case AppModule.lots:
        return AnimalLotsScreen(store: lots, production: settings.production!, today: today);
      case AppModule.lotsOeufs:
      case AppModule.couvaison:
        return IncubationLotsScreen(store: lots, today: today);
      case AppModule.eclosions:
        return IncubationLotsScreen(store: lots, today: today, onlyToRecord: true);
      case AppModule.calendrierCouvaison:
        return IncubationCalculator(today: today, store: lots);
      case AppModule.parametres:
        return SettingsScreen(settings: settings);
      default:
        return _Placeholder(module: module);
    }
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.module});
  final AppModule module;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(moduleIcon(module), size: 40, color: NafaColors.textMuted),
          const SizedBox(height: 12),
          Text(module.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Ce module sera construit dans un prochain lot.',
              textAlign: TextAlign.center, style: TextStyle(color: NafaColors.textMuted)),
        ]),
      ),
    );
  }
}
