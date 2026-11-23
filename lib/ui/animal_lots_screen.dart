import 'package:material_ui/material_ui.dart';

import '../data/lot_store.dart';
import '../domain/format.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import 'config_scope.dart';
import 'theme.dart';
import 'widgets.dart';


/// Liste des lots de sujets de la production active.
class AnimalLotsScreen extends StatelessWidget {
  const AnimalLotsScreen({super.key, required this.store, required this.production, required this.today});
  final LotStore store;
  final ProductionType production;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final lots = store.animalLots(production);
        final active = lots.where((l) => l.status == LotStatus.enCours).toList();
        final present = active.fold(0, (s, l) => s + l.current);
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            key: const ValueKey('nouveau-lot'),
            onPressed: () => openAnimalLotForm(context, store, production, today),
            icon: const Icon(Icons.add),
            label: const Text('Nouveau lot'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text('Lots et sujets · ${production.label}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${active.length} lot(s) en cours · ${formatInt(present)} sujets présents',
                  style: const TextStyle(color: NafaColors.textMuted)),
              const SizedBox(height: 12),
              if (lots.isEmpty)
                const EmptyState(
                  icon: Icons.grid_view_outlined,
                  title: 'Aucun lot',
                  message: 'Créez votre premier lot : date, race et nombre de sujets. L’âge se calcule tout seul.',
                ),
              for (final l in lots) ...[
                _AnimalLotTile(lot: l, today: today, onTap: () => _open(context, l)),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  void _open(BuildContext context, AnimalLot lot) => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AnimalLotDetailScreen(store: store, lot: lot, today: today)));
}

class _AnimalLotTile extends StatelessWidget {
  const _AnimalLotTile({required this.lot, required this.today, required this.onTap});
  final AnimalLot lot;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          key: ValueKey('lot-${lot.code}'),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${lot.code} · ${lot.breed}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                StatusChip.lot(lot.status),
              ]),
              const SizedBox(height: 6),
              Text(
                '${formatInt(lot.current)} sujets sur ${formatInt(lot.initialCount)} · '
                '${lot.ageAt(today)} jours · mortalité ${formatPercent(lot.mortalityRate)}',
                style: const TextStyle(color: NafaColors.textMuted),
              ),
              if (lot.objective != null)
                Text(lot.objective!.label, style: const TextStyle(color: NafaColors.textMuted)),
            ]),
          ),
        ),
      );
}

Future<void> openAnimalLotForm(BuildContext context, LotStore store, ProductionType p, DateTime today) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true, builder: (_) => AnimalLotForm(store: store, production: p, today: today)));

class AnimalLotForm extends StatefulWidget {
  const AnimalLotForm({super.key, required this.store, required this.production, required this.today});
  final LotStore store;
  final ProductionType production;
  final DateTime today;

  @override
  State<AnimalLotForm> createState() => _AnimalLotFormState();
}

class _AnimalLotFormState extends State<AnimalLotForm> {
  final _form = GlobalKey<FormState>();
  final _breed = TextEditingController();
  final _count = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _date = widget.today;
  LotObjective? _objective;

  @override
  void initState() {
    super.initState();
    if (widget.production == ProductionType.ameliorees) _objective = LotObjective.engraissement;
  }

  @override
  void dispose() {
    _breed.dispose();
    _count.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      final lot = AnimalLot(
        id: widget.store.newId(),
        code: widget.store.nextAnimalCode(widget.production, _date),
        production: widget.production,
        breed: _breed.text.trim(),
        startDate: _date,
        initialCount: int.parse(_count.text),
        objective: _objective,
        notes: _notes.text.trim(),
      );
      await widget.store.addAnimalLot(lot);
      if (mounted) {
        Navigator.of(context).pop();
        showInfo(context, 'Lot ${lot.code} créé.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.store.nextAnimalCode(widget.production, _date);
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau lot')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InfoRow('Code attribué automatiquement', code),
            const SizedBox(height: 12),
            DateField(
              label: 'Date de démarrage du lot',
              value: _date,
              last: widget.today,
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('race'),
              controller: _breed,
              decoration: const InputDecoration(labelText: 'Race ou souche', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            // Choix rapide : un appui suffit, sans rien écrire.
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final b in ConfigScope.of(context).breedsFor(widget.production))
                ChoiceChip(
                  label: Text(b),
                  selected: _breed.text == b,
                  onSelected: (_) => setState(() => _breed.text = b),
                ),
            ]),
            const SizedBox(height: 12),
            IntField(key: const ValueKey('effectif'), controller: _count, label: 'Nombre de sujets au départ', suffix: 'sujets', min: 1),
            if (widget.production == ProductionType.ameliorees) ...[
              const SizedBox(height: 12),
              const Text('Objectif du lot', style: TextStyle(fontWeight: FontWeight.w600)),
              RadioGroup<LotObjective>(
                groupValue: _objective,
                onChanged: (v) => setState(() => _objective = v),
                child: Column(children: [
                  for (final o in LotObjective.values)
                    RadioListTile<LotObjective>(value: o, title: Text(o.label), contentPadding: EdgeInsets.zero),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Observations (facultatif)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton(key: const ValueKey('enregistrer'), onPressed: _save, child: const Text('Enregistrer le lot')),
          ],
        ),
      ),
    );
  }
}

class AnimalLotDetailScreen extends StatelessWidget {
  const AnimalLotDetailScreen({super.key, required this.store, required this.lot, required this.today});
  final LotStore store;
  final AnimalLot lot;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(lot.code)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(title: lot.breed, trailing: StatusChip.lot(lot.status), children: [
              InfoRow('Démarré le', formatDate(lot.startDate)),
              if (lot.isChickBand)
                InfoRow('Origine', lot.origins.entries.map((e) => '${e.key} : ${formatInt(e.value)}').join('\n')),
              InfoRow('Âge', '${lot.ageAt(today)} jours (${(lot.ageAt(today) / 7).toStringAsFixed(1).replaceAll('.', ',')} semaines)'),
              InfoRow('Effectif de départ', '${formatInt(lot.initialCount)} sujets'),
              InfoRow('Effectif actuel', '${formatInt(lot.current)} sujets'),
              InfoRow('Mortalité cumulée', '${formatInt(lot.dead)} sujets · ${formatPercent(lot.mortalityRate)}',
                  valueColor: lot.mortalityRate >= 0.05 ? NafaColors.urgent : null),
              for (final t in [MovementType.vente, MovementType.reforme, MovementType.autre])
                if (lot.countOf(t) > 0) InfoRow(t.label, '${formatInt(lot.countOf(t))} sujets'),
              if (lot.objective != null) InfoRow('Objectif', lot.objective!.label),
              if (lot.notes.isNotEmpty) InfoRow('Observations', lot.notes),
            ]),
            if (lot.production == ProductionType.ameliorees && lot.objective != LotObjective.engraissement) ...[
              const SizedBox(height: 12),
              _CycleCard(lot: lot, today: today),
            ],
            const SizedBox(height: 12),
            if (lot.status == LotStatus.enCours)
              FilledButton.icon(
                key: const ValueKey('saisir-sortie'),
                onPressed: () => movementDialog(context),
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Enregistrer une mortalité ou une sortie'),
              ),
            const SizedBox(height: 12),
            SectionCard(title: 'Historique', children: [
              if (lot.movements.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Aucune sortie enregistrée.', style: TextStyle(color: NafaColors.textMuted)),
                ),
              for (final m in lot.movements.reversed)
                InfoRow('${formatDate(m.date)} · ${m.type.label}${m.note.isEmpty ? '' : ' (${m.note})'}',
                    '${formatInt(m.count)} sujets'),
            ]),
            const SizedBox(height: 12),
            if (lot.status == LotStatus.enCours)
              OutlinedButton(
                onPressed: () async {
                  final ok = await _confirm(context, 'Clôturer le lot ?',
                      'Le lot passera en « Terminé ». Son historique est conservé.');
                  if (ok) {
                    lot.closed = true;
                    await store.changed();
                  }
                },
                child: const Text('Clôturer le lot'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> movementDialog(BuildContext context) async {
    final count = TextEditingController();
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    var type = MovementType.mortalite;
    var date = today;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Mortalité ou sortie'),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<MovementType>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: [for (final t in MovementType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                  onChanged: (t) => setState(() => type = t ?? type),
                ),
                const SizedBox(height: 12),
                IntField(key: const ValueKey('nombre-sortie'), controller: count, label: 'Nombre de sujets', min: 1, max: lot.current),
                const SizedBox(height: 12),
                DateField(label: 'Date', value: date, first: lot.startDate, last: today, onChanged: (d) => setState(() => date = d)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Remarque (facultatif)', border: OutlineInputBorder()),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton(
              key: const ValueKey('valider-sortie'),
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                try {
                  lot.addMovement(Movement(date: date, type: type, count: int.parse(count.text), note: note.text.trim()));
                  await store.changed();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (e) {
                  if (dialogContext.mounted) showError(dialogContext, e);
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmer')),
        ],
      ),
    ) ??
    false;

/// Repères du cycle d'une race améliorée (Paramètres > cycle par race).
/// Ce sont des contrôles : la réforme reste une décision du producteur.
class _CycleCard extends StatelessWidget {
  const _CycleCard({required this.lot, required this.today});
  final AnimalLot lot;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final steps = ConfigScope.of(context).cycleFor(lot.breed).milestones(lot.startDate);
    final t = DateTime(today.year, today.month, today.day);
    final next = steps.where((s) => !s.$2.isBefore(t)).firstOrNull;
    return SectionCard(title: 'Cycle ${lot.breed}', children: [
      for (final s in steps)
        InfoRow(
          s.$1,
          s.$2.isBefore(t) ? '${formatDate(s.$2)} · passé' : formatDate(s.$2),
          valueColor: identical(s, next) ? NafaColors.green : (s.$2.isBefore(t) ? NafaColors.textMuted : null),
        ),
      const SizedBox(height: 4),
      const Text('Repères modifiables dans Paramètres. La réforme n’est jamais automatique.',
          style: TextStyle(color: NafaColors.textMuted, fontSize: 12)),
    ]);
  }
}
