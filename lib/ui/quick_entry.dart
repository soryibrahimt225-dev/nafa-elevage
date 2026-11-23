import 'package:material_ui/material_ui.dart';

import '../data/app_data.dart';
import '../domain/feed.dart';
import '../domain/format.dart';
import '../domain/health.dart';
import '../domain/incubation.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import 'animal_lots_screen.dart';
import 'feed_screen.dart';
import 'finance_screens.dart';
import 'health_screen.dart';
import 'incubation_lots_screen.dart';
import 'laying_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Bouton principal « Saisir » : un seul point d'entrée pour les saisies
/// courantes de la production choisie (dossier, section 8).
class QuickEntryButton extends StatelessWidget {
  const QuickEntryButton({super.key, required this.data, required this.today});
  final AppData data;
  final DateTime today;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        key: const ValueKey('saisir'),
        onPressed: () => showQuickEntry(context, data, today),
        icon: const Icon(Icons.add),
        label: const Text('Saisir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}

class _Action {
  const _Action(this.key, this.icon, this.label, this.help, this.run);
  final String key;
  final IconData icon;
  final String label;
  final String help;
  final Future<void> Function(BuildContext context) run;
}

Future<void> showQuickEntry(BuildContext context, AppData data, DateTime today) async {
  final actions = _actionsFor(data, today);
  final chosen = await showModalBottomSheet<_Action>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text('Que voulez-vous saisir ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          for (final a in actions)
            ListTile(
              key: ValueKey('saisir-${a.key}'),
              leading: CircleAvatar(
                backgroundColor: NafaColors.greenLight,
                foregroundColor: NafaColors.green,
                child: Icon(a.icon),
              ),
              title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(a.help),
              onTap: () => Navigator.pop(sheet, a),
            ),
        ]),
      ),
    ),
  );
  if (chosen != null && context.mounted) await chosen.run(context);
}

List<_Action> _actionsFor(AppData data, DateTime today) {
  final p = data.settings.production!;
  final ctx = FinanceContext(
      finance: data.finance, lots: data.lots, production: p, options: data.settings.options, today: today);
  final sale = _Action('vente', Icons.point_of_sale_outlined, 'Une vente', 'Produit, quantité, prix, encaissement',
      (c) => Navigator.of(c).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => SaleForm(ctx: ctx))));
  final expense = _Action('depense', Icons.receipt_long_outlined, 'Une dépense', 'Aliment, vaccins, transport, main-d’œuvre…',
      (c) => Navigator.of(c).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => ExpenseForm(ctx: ctx))));

  if (p == ProductionType.couveuse) {
    return [
      _Action('oeufs-couveuse', Icons.egg_outlined, 'Mettre des œufs en couveuse', 'Nouveau lot : dates calculées',
          (c) => Navigator.of(c).push(MaterialPageRoute<void>(
              fullscreenDialog: true, builder: (_) => IncubationLotForm(store: data.lots, today: today)))),
      _Action('eclosion', Icons.egg_alt_outlined, 'Une éclosion', 'Poussins éclos et morts à l’éclosion', (c) async {
        final lots = data.lots.incubationLots.where((l) {
          final s = l.statusAt(today);
          return s == IncubationStatus.eclosionImminente || s == IncubationStatus.aVerifier || s == IncubationStatus.descenteFaite;
        }).toList()
          ..sort((a, b) => a.schedule.hatchDate.compareTo(b.schedule.hatchDate));
        final lot = await _pick(c, 'Quel lot a éclos ?', lots,
            (l) => '${l.code} · ${formatInt(l.eggsSet)} œufs · prévu le ${formatDate(l.schedule.hatchDate)}',
            empty: 'Aucun lot n’attend son éclosion.');
        if (lot != null && c.mounted) {
          await IncubationLotDetailScreen(store: data.lots, lot: lot, today: today).hatchDialog(c);
        }
      }),
      _mortality(data, today, ProductionType.couveuse, label: 'Une mortalité (poussins gardés)'),
      sale,
      expense,
    ];
  }

  final laying = p == ProductionType.pondeuses || p == ProductionType.ameliorees;
  return [
    _mortality(data, today, p),
    if (laying)
      _Action('ponte', Icons.egg_outlined, 'Les œufs ramassés', 'Ramassés, cassés, fertiles', (c) async {
        final screen = LayingScreen(data: data, today: today);
        final lot = await _pick(c, 'Quel lot ?', screen.layingLots,
            (l) => '${l.code} · ${l.breed} · ${formatInt(l.current)} sujets',
            empty: 'Aucun lot en ponte.');
        if (lot != null && c.mounted) {
          await LotLayingCard(screen: screen, lot: lot).entry(c, data.eggs.find(lot.code, today));
        }
      }),
    _Action('aliment', Icons.grass_outlined, 'L’aliment distribué', 'Quantité donnée à un lot', (c) async {
      final stocks = data.feed.stocks.values.where((s) => s.remainingGrams > 0).toList();
      final item = await _pick<FeedStock>(c, 'Quel aliment ?', stocks,
          (s) => '${s.item.name} · ${formatKg(s.remainingGrams)} en stock',
          empty: 'Aucun aliment en stock. Enregistrez d’abord un achat dans « Alimentation ».');
      if (item == null || !c.mounted) return;
      final lots = data.lots.animalLots(p).where((l) => l.status == LotStatus.enCours).toList();
      if (lots.isEmpty) {
        showError(c, 'Aucun lot en cours.');
        return;
      }
      await FeedScreen(data: data, today: today).distribute(c, item.item, lots, loss: false);
    }),
    _Action('soin', Icons.medical_services_outlined, 'Un soin réalisé', 'Vaccination ou traitement prévu', (c) async {
      final codes = {for (final l in data.lots.animalLots(p)) l.code};
      final due = data.health
          .forLots(codes, today)
          .where((r) => r.statusAt(today) == HealthStatus.enRetard || r.statusAt(today) == HealthStatus.aujourdhui)
          .toList();
      final r = await _pick<HealthRecord>(c, 'Quel soin ?', due, (r) => '${r.lotCode} · ${r.title}',
          empty: 'Aucun soin prévu aujourd’hui ni en retard. Prévoyez les soins dans « Santé et vaccination ».');
      if (r != null && c.mounted) {
        await HealthScreen(health: data.health, lots: data.lots, production: p, today: today).detail(c, r);
      }
    }),
    sale,
    expense,
  ];
}

_Action _mortality(AppData data, DateTime today, ProductionType p, {String label = 'Une mortalité ou une sortie'}) =>
    _Action('mortalite', Icons.remove_circle_outline, label, 'Sujets morts, vendus ou réformés', (c) async {
      final lots = data.lots.animalLots(p).where((l) => l.status == LotStatus.enCours).toList();
      final lot = await _pick(c, 'Quel lot ?', lots, (l) => '${l.code} · ${l.breed} · ${formatInt(l.current)} sujets',
          empty: p == ProductionType.couveuse ? 'Aucune bande de poussins gardés.' : 'Aucun lot en cours.');
      if (lot != null && c.mounted) {
        await AnimalLotDetailScreen(store: data.lots, lot: lot, today: today).movementDialog(c);
      }
    });

/// Choix d'un élément ; s'il n'y en a qu'un, il est pris directement.
Future<T?> _pick<T>(BuildContext context, String title, List<T> items, String Function(T) label,
    {required String empty}) async {
  if (items.isEmpty) {
    showInfo(context, empty);
    return null;
  }
  if (items.length == 1) return items.single;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          for (final (i, it) in items.indexed)
            ListTile(key: ValueKey('choix-$i'), title: Text(label(it)), onTap: () => Navigator.pop(sheet, it)),
        ]),
      ),
    ),
  );
}
