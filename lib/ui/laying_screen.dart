import 'package:material_ui/material_ui.dart';

import '../data/app_data.dart';
import '../domain/eggs.dart';
import '../domain/finance.dart';
import '../domain/format.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import 'theme.dart';
import 'widgets.dart';

/// Ponte et œufs (pondeuses) ou Ponte, maintien et réforme (races
/// améliorées). Saisie du ramassage quotidien, taux de ponte, réforme
/// décidée par le producteur (jamais automatique).
class LayingScreen extends StatelessWidget {
  const LayingScreen({super.key, required this.data, required this.today});
  final AppData data;
  final DateTime today;

  ProductionType get _production => data.settings.production!;

  bool get fertileEnabled =>
      _production == ProductionType.ameliorees ||
      data.settings.options.contains(OptionalFeature.couveusePondeuses) ||
      data.settings.options.contains(OptionalFeature.couvaisonConversion);

  /// Lots concernés par la ponte.
  List<AnimalLot> get layingLots => data.lots
      .animalLots(_production)
      .where((l) =>
          l.status == LotStatus.enCours &&
          (_production == ProductionType.pondeuses || l.objective != LotObjective.engraissement))
      .toList();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([data.lots, data.eggs, data.finance]),
        builder: (context, _) {
          final lots = layingLots;
          final codes = {for (final l in lots) l.code};
          final weekStart = DateTime(today.year, today.month, today.day - 6);
          final week = EggSummary(data.eggs.between(codes, weekStart, today));
          final todayRecords = data.eggs.between(codes, today, today);
          final hens = lots.fold(0, (s, l) => s + l.current);
          final todayCollected = todayRecords.fold(0, (s, r) => s + r.collected);
          final sold = data.finance.sales
              .where((s) =>
                  s.production == _production &&
                  (s.category == SaleCategory.oeufsTable || s.category == SaleCategory.oeufsFertiles) &&
                  !s.date.isBefore(weekStart))
              .fold(0, (n, s) => n + s.quantity);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_production == ProductionType.pondeuses ? 'Ponte et œufs' : 'Ponte, maintien et réforme',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${lots.length} lot(s) en ponte · ${formatInt(hens)} sujets',
                  style: const TextStyle(color: NafaColors.textMuted)),
              const SizedBox(height: 12),
              SectionCard(title: 'Aujourd’hui', children: [
                InfoRow('Œufs ramassés', formatInt(todayCollected)),
                InfoRow('Taux de ponte', formatPercent(layingRate(todayCollected, hens))),
                InfoRow('Lots saisis', '${todayRecords.length} sur ${lots.length}',
                    valueColor: todayRecords.length < lots.length ? NafaColors.watch : null),
              ]),
              const SizedBox(height: 12),
              SectionCard(title: '7 derniers jours', children: [
                InfoRow('Œufs ramassés', formatInt(week.collected)),
                InfoRow('Œufs cassés', '${formatInt(week.broken)} · ${formatPercent(week.brokenRate)}'),
                if (fertileEnabled) InfoRow('Œufs fertiles mis de côté', formatInt(week.fertile)),
                InfoRow('Œufs de table', formatInt(week.table)),
                InfoRow('Œufs vendus', formatInt(sold)),
              ]),
              const SizedBox(height: 12),
              if (lots.isEmpty)
                EmptyState(
                  icon: Icons.egg_outlined,
                  title: 'Aucun lot en ponte',
                  message: _production == ProductionType.pondeuses
                      ? 'Créez un lot dans « Lots et sujets ».'
                      : 'Créez un lot avec l’objectif « ponte » ou « reproduction » dans « Lots et sujets ».',
                ),
              for (final l in lots) ...[
                LotLayingCard(screen: this, lot: l),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      );
}

class LotLayingCard extends StatelessWidget {
  const LotLayingCard({super.key, required this.screen, required this.lot});
  final LayingScreen screen;
  final AnimalLot lot;

  @override
  Widget build(BuildContext context) {
    final today = screen.today;
    final rec = screen.data.eggs.find(lot.code, today);
    final weekRecords = screen.data.eggs.between({lot.code}, DateTime(today.year, today.month, today.day - 6), today);
    final weekCollected = weekRecords.fold(0, (s, r) => s + r.collected);
    final weekHens = weekRecords.fold(0, (s, r) => s + lot.countAt(r.date));
    return SectionCard(
      title: '${lot.code} · ${lot.breed}',
      children: [
        InfoRow('Sujets présents', '${formatInt(lot.current)} · ${lot.ageAt(today)} jours'),
        InfoRow('Aujourd’hui', rec == null ? 'pas encore saisi' : '${formatInt(rec.collected)} œufs · ${formatPercent(layingRate(rec.collected, lot.countAt(today)))}',
            valueColor: rec == null ? NafaColors.watch : null),
        InfoRow('Taux moyen sur 7 jours', formatPercent(layingRate(weekCollected, weekHens))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            key: ValueKey('saisir-ponte-${lot.code}'),
            onPressed: () => entry(context, rec),
            icon: const Icon(Icons.egg_outlined),
            label: Text(rec == null ? 'Saisir la ponte' : 'Corriger la ponte'),
          ),
          OutlinedButton.icon(
            key: ValueKey('reformer-${lot.code}'),
            onPressed: () => _reform(context),
            icon: const Icon(Icons.logout),
            label: const Text('Réformer des sujets'),
          ),
        ]),
      ],
    );
  }

  Future<void> entry(BuildContext context, EggRecord? existing) async {
    final collected = TextEditingController(text: existing?.collected.toString() ?? '');
    final broken = TextEditingController(text: existing?.broken.toString() ?? '');
    final fertile = TextEditingController(text: existing?.fertile.toString() ?? '');
    final form = GlobalKey<FormState>();
    final hens = lot.countAt(screen.today);
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Ponte du jour · ${lot.code}'),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${formatInt(hens)} sujets présents', style: const TextStyle(color: NafaColors.textMuted)),
              const SizedBox(height: 12),
              // Une poule pond au plus un œuf par jour.
              IntField(key: const ValueKey('ramasses'), controller: collected, label: 'Œufs ramassés', max: hens),
              const SizedBox(height: 12),
              IntField(key: const ValueKey('casses'), controller: broken, label: 'Œufs cassés', optional: true),
              if (screen.fertileEnabled) ...[
                const SizedBox(height: 12),
                IntField(controller: fertile, label: 'Œufs fertiles mis de côté', optional: true),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(
            key: const ValueKey('valider-ponte'),
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                await screen.data.eggs.save(EggRecord(
                  lotCode: lot.code,
                  date: screen.today,
                  collected: int.parse(collected.text),
                  broken: int.tryParse(broken.text) ?? 0,
                  fertile: int.tryParse(fertile.text) ?? 0,
                ));
                if (d.mounted) Navigator.pop(d);
              } catch (e) {
                if (d.mounted) showError(d, e);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _reform(BuildContext context) async {
    final count = TextEditingController();
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Réformer des sujets'),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Sortie de sujets devenus moins productifs ou que vous décidez de vendre. '
              'Pour une vente, enregistrez aussi la vente dans « Ventes ».',
              style: TextStyle(color: NafaColors.textMuted),
            ),
            const SizedBox(height: 12),
            IntField(key: const ValueKey('nombre-reforme'), controller: count, label: 'Nombre de sujets', min: 1, max: lot.current),
            const SizedBox(height: 12),
            TextFormField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Motif (facultatif)', border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(
            key: const ValueKey('valider-reforme'),
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                lot.addMovement(Movement(
                    date: screen.today, type: MovementType.reforme, count: int.parse(count.text), note: note.text.trim()));
                await screen.data.lots.changed();
                if (d.mounted) Navigator.pop(d);
              } catch (e) {
                if (d.mounted) showError(d, e);
              }
            },
            child: const Text('Confirmer la réforme'),
          ),
        ],
      ),
    );
  }
}
