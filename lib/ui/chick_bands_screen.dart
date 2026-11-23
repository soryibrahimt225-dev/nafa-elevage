import 'package:material_ui/material_ui.dart';

import '../data/app_data.dart';
import '../domain/format.dart';
import '../domain/health.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import 'animal_lots_screen.dart';
import 'health_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Poussins gardés pour l'élevage : bandes (EL-AA-NNN) constituées à partir
/// des éclosions du producteur, avec mortalité, ventes et âge.
class ChickBandsScreen extends StatelessWidget {
  const ChickBandsScreen({super.key, required this.data, required this.today});
  final AppData data;
  final DateTime today;

  List<AnimalLot> get _bands => data.lots.animalLots(ProductionType.couveuse);

  ChickBalance balance(IncubationLot l) =>
      ChickBalance(lot: l, bands: _bands, sold: data.finance.chicksSoldFrom(l.code));

  /// Éclosions du producteur dont il reste des poussins à répartir.
  List<(IncubationLot, int)> get available => [
        for (final l in data.lots.incubationLots)
          if (l.ownerType == OwnerType.producteur && l.hasResult && balance(l).available > 0)
            (l, balance(l).available),
      ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([data.lots, data.finance, data.health]),
        builder: (context, _) {
          final bands = _bands;
          final active = bands.where((b) => b.status == LotStatus.enCours).toList();
          final initial = bands.fold(0, (s, b) => s + b.initialCount);
          final dead = bands.fold(0, (s, b) => s + b.dead);
          final avail = available;
          return Scaffold(
            floatingActionButton: avail.isEmpty
                ? null
                : FloatingActionButton.extended(
                    key: const ValueKey('nouvelle-bande'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        fullscreenDialog: true, builder: (_) => ChickBandForm(screen: this))),
                    icon: const Icon(Icons.add),
                    label: const Text('Garder des poussins'),
                  ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                const Text('Poussins gardés', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Les poussins que vous ne vendez pas à l’éclosion.', style: TextStyle(color: NafaColors.textMuted)),
                const SizedBox(height: 12),
                SectionCard(title: 'Élevage', children: [
                  InfoRow('Bandes en cours', formatInt(active.length)),
                  InfoRow('Poussins mis en élevage', formatInt(initial)),
                  InfoRow('Effectif actuel', '${formatInt(active.fold(0, (s, b) => s + b.current))} sujets'),
                  InfoRow('Mortalité en élevage', initial == 0 ? '—' : '${formatInt(dead)} · ${formatPercent(dead / initial)}'),
                ]),
                if (bands.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _HealthCard(screen: this, bands: bands),
                ],
                const SizedBox(height: 12),
                SectionCard(title: 'Poussins disponibles après éclosion', children: [
                  if (avail.isEmpty)
                    const Text('Aucun poussin à répartir. Saisissez d’abord le résultat d’une éclosion.',
                        style: TextStyle(color: NafaColors.textMuted)),
                  for (final (l, n) in avail)
                    InfoRow('${l.code} · éclos le ${formatDate(l.schedule.hatchDate)}', '${formatInt(n)} poussins'),
                ]),
                const SizedBox(height: 12),
                if (bands.isEmpty)
                  const EmptyState(
                    icon: Icons.pets_outlined,
                    title: 'Aucune bande',
                    message: 'Créez une bande avec les poussins gardés d’une ou plusieurs éclosions.',
                  ),
                for (final b in bands) ...[
                  Card(
                    child: InkWell(
                      key: ValueKey('bande-${b.code}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => AnimalLotDetailScreen(store: data.lots, lot: b, today: today))),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text('${b.code} · ${b.breed}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ),
                            StatusChip.lot(b.status),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            '${formatInt(b.current)} sujets sur ${formatInt(b.initialCount)} · ${b.ageAt(today)} jours · '
                            'mortalité ${formatPercent(b.mortalityRate)}',
                            style: const TextStyle(color: NafaColors.textMuted),
                          ),
                          Text('Origine : ${b.origins.entries.map((e) => '${e.key} (${formatInt(e.value)})').join(', ')}',
                              style: const TextStyle(color: NafaColors.textMuted)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      );
}

class ChickBandForm extends StatefulWidget {
  const ChickBandForm({super.key, required this.screen});
  final ChickBandsScreen screen;

  @override
  State<ChickBandForm> createState() => _ChickBandFormState();
}

class _ChickBandFormState extends State<ChickBandForm> {
  final _form = GlobalKey<FormState>();
  late final List<(IncubationLot, int)> _sources = widget.screen.available;
  late final Map<String, TextEditingController> _counts = {
    for (final (l, _) in _sources) l.code: TextEditingController(),
  };
  late final _label = TextEditingController(text: _sources.isEmpty ? '' : _sources.first.$1.speciesLabel);
  final _notes = TextEditingController();
  late DateTime _date = widget.screen.today;

  @override
  void dispose() {
    for (final c in [..._counts.values, _label, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _total => _counts.values.fold(0, (s, c) => s + (int.tryParse(c.text) ?? 0));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final origins = {
      for (final e in _counts.entries)
        if ((int.tryParse(e.value.text) ?? 0) > 0) e.key: int.parse(e.value.text),
    };
    final store = widget.screen.data.lots;
    try {
      final band = AnimalLot(
        id: store.newId(),
        code: store.nextAnimalCode(ProductionType.couveuse, _date),
        production: ProductionType.couveuse,
        breed: _label.text.trim(),
        startDate: _date,
        initialCount: _total,
        origins: origins,
        notes: _notes.text.trim(),
      );
      await store.addAnimalLot(band);
      if (mounted) {
        Navigator.of(context).pop();
        showInfo(context, 'Bande ${band.code} créée avec ${formatInt(band.initialCount)} poussins.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.screen.data.lots;
    return Scaffold(
      appBar: AppBar(title: const Text('Garder des poussins')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InfoRow('Code attribué automatiquement', store.nextAnimalCode(ProductionType.couveuse, _date)),
            const SizedBox(height: 8),
            const Text('Combien de poussins gardez-vous de chaque éclosion ?', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final (l, n) in _sources) ...[
              Row(children: [
                Expanded(
                  child: IntField(
                    key: ValueKey('garder-${l.code}'),
                    controller: _counts[l.code]!,
                    label: '${l.code} (${formatInt(n)} disponibles)',
                    suffix: 'poussins',
                    optional: true,
                    max: n,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _counts[l.code]!.text = '$n'),
                  child: const Text('Tout'),
                ),
              ]),
              const SizedBox(height: 10),
            ],
            Card(
              color: NafaColors.greenLight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: InfoRow('Poussins dans la bande', formatInt(_total)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Espèce ou race', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            DateField(
              label: 'Date de début de la bande',
              value: _date,
              last: widget.screen.today,
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Observations (facultatif)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('enregistrer'),
              onPressed: _total == 0 ? null : _save,
              child: const Text('Créer la bande'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accès à la santé et à la vaccination des bandes (et seulement des
/// bandes : les lots d'œufs n'ont pas de vaccination).
class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.screen, required this.bands});
  final ChickBandsScreen screen;
  final List<AnimalLot> bands;

  @override
  Widget build(BuildContext context) {
    final today = screen.today;
    final records = screen.data.health.forLots({for (final b in bands) b.code}, today);
    final late = records.where((r) => r.statusAt(today) == HealthStatus.enRetard).length;
    final todayCount = records.where((r) => r.statusAt(today) == HealthStatus.aujourdhui).length;
    final next = records.where((r) => r.statusAt(today) == HealthStatus.aVenir).firstOrNull;
    return SectionCard(title: 'Santé et vaccination des bandes', children: [
      InfoRow('En retard', formatInt(late), valueColor: late > 0 ? NafaColors.urgent : null),
      InfoRow('Aujourd’hui', formatInt(todayCount), valueColor: todayCount > 0 ? NafaColors.watch : null),
      if (next != null) InfoRow('Prochain soin', '${next.lotCode} · ${next.title} · ${formatDate(next.plannedDate)}'),
      const SizedBox(height: 8),
      FilledButton.icon(
        key: const ValueKey('sante-bandes'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Santé des poussins gardés')),
            body: HealthScreen(
                health: screen.data.health, lots: screen.data.lots, production: ProductionType.couveuse, today: today),
          ),
        )),
        icon: const Icon(Icons.medical_services_outlined),
        label: const Text('Voir et prévoir les soins'),
      ),
    ]);
  }
}
