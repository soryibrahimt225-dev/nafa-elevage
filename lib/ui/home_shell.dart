import 'package:material_ui/material_ui.dart';

import '../data/settings_store.dart';
import '../domain/format.dart';
import '../domain/production.dart';
import 'icons.dart';
import 'incubation_calculator.dart';
import 'settings_screen.dart';
import 'theme.dart';

/// Structure principale : menu dynamique selon la production choisie.
/// Écran large : menu latéral fixe. Téléphone : menu dans un tiroir.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.settings, this.today});
  final FarmSettings settings;
  final DateTime? today;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppModule _current = AppModule.tableauDeBord;

  void _go(AppModule m) => setState(() => _current = m);

  @override
  Widget build(BuildContext context) {
    final modules = widget.settings.modules;
    if (!modules.contains(_current)) _current = AppModule.tableauDeBord;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final production = widget.settings.production!;

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
      settings: widget.settings,
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
  const _ModulePage({required this.module, required this.settings, required this.today});
  final AppModule module;
  final FarmSettings settings;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    switch (module) {
      case AppModule.tableauDeBord:
        return _Dashboard(settings: settings, today: today);
      case AppModule.calendrierCouvaison:
      case AppModule.couvaison:
        return IncubationCalculator(today: today);
      case AppModule.parametres:
        return SettingsScreen(settings: settings);
      default:
        return _Placeholder(module: module);
    }
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.settings, required this.today});
  final FarmSettings settings;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final p = settings.production!;
    final kpis = _kpisFor(p);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(formatLongDate(today).toUpperCase(),
            style: const TextStyle(fontSize: 12, color: NafaColors.textMuted, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(p.label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        Text(p.description, style: const TextStyle(color: NafaColors.textMuted)),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 4 : 2;
          const gap = 10.0;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final k in kpis)
              SizedBox(
                width: w,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k.$1, style: const TextStyle(fontSize: 13, color: NafaColors.textMuted)),
                      const SizedBox(height: 6),
                      Text(k.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Aucune donnée enregistrée pour l’instant. Les chiffres apparaîtront dès '
              'la saisie du premier lot, de la première vente ou de la première dépense.',
              style: TextStyle(color: NafaColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  /// Indicateurs prioritaires par production (valeurs vides tant que rien
  /// n'est saisi : aucune donnée inventée).
  List<(String, String)> _kpisFor(ProductionType p) {
    final money = formatFcfa(0);
    final common = [
      ('Chiffre d’affaires', money),
      ('Dépenses', money),
      ('Bénéfice estimé', money),
    ];
    switch (p) {
      case ProductionType.chair:
        return [...common, ('Sujets présents', '0 sujet'), ('Lots en cours', '0'), ('Mortalité', '—')];
      case ProductionType.ameliorees:
        return [...common, ('Sujets présents', '0 sujet'), ('Lots en cours', '0'), ('Mortalité', '—')];
      case ProductionType.pondeuses:
        return [...common, ('Sujets en ponte', '0 sujet'), ('Œufs du jour', '0 œuf'), ('Taux de ponte', '—')];
      case ProductionType.couveuse:
        return [...common, ('Œufs en incubation', '0 œuf'), ('Lots en cours', '0'), ('Taux d’éclosion', '—')];
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
