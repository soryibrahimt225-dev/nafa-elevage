import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/excel_import.dart';
import '../data/lot_store.dart';
import '../domain/format.dart';
import '../domain/incubation.dart';
import '../domain/lots.dart';
import 'theme.dart';
import 'widgets.dart';

/// Lots d'œufs de la couveuse.
class IncubationLotsScreen extends StatelessWidget {
  const IncubationLotsScreen({super.key, required this.store, required this.today, this.onlyToRecord = false});
  final LotStore store;
  final DateTime today;

  /// Mode « Éclosions » : seulement les lots dont le résultat est attendu.
  final bool onlyToRecord;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        var lots = store.incubationLots;
        if (onlyToRecord) {
          lots = lots.where((l) {
            final s = l.statusAt(today);
            return s == IncubationStatus.eclosionImminente || s == IncubationStatus.aVerifier;
          }).toList()
            ..sort((a, b) => a.schedule.hatchDate.compareTo(b.schedule.hatchDate));
        }
        final running = store.incubationLots.where((l) => !l.hasResult && l.statusAt(today) != IncubationStatus.aVerifier);
        final eggs = running.fold(0, (s, l) => s + l.eggsSet);
        return Scaffold(
          floatingActionButton: onlyToRecord
              ? null
              : FloatingActionButton.extended(
                  key: const ValueKey('nouveau-lot-oeufs'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      fullscreenDialog: true, builder: (_) => IncubationLotForm(store: store, today: today))),
                  icon: const Icon(Icons.add),
                  label: const Text('Mettre des œufs'),
                ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(onlyToRecord ? 'Éclosions à enregistrer' : 'Lots d’œufs',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                onlyToRecord
                    ? 'Lots dont l’éclosion est prévue ou passée sans résultat saisi.'
                    : '${running.length} lot(s) en incubation · ${formatInt(eggs)} œufs',
                style: const TextStyle(color: NafaColors.textMuted),
              ),
              if (!onlyToRecord) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _import(context),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Importer depuis le classeur Excel'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (lots.isEmpty)
                EmptyState(
                  icon: onlyToRecord ? Icons.check_circle_outline : Icons.egg_outlined,
                  title: onlyToRecord ? 'Rien à enregistrer' : 'Aucun lot d’œufs',
                  message: onlyToRecord
                      ? 'Toutes les éclosions passées ont un résultat.'
                      : 'Ajoutez un lot : date, espèce et nombre d’œufs. Les dates se calculent seules.',
                ),
              for (final l in lots) ...[
                IncubationLotTile(lot: l, today: today, onTap: () => openIncubationLot(context, store, l, today)),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _import(BuildContext context) async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx']);
    if (picked.isEmpty) return;
    final bytes = await picked.single.readAsBytes();
    if (!context.mounted) return;
    final result = importCouvoirWorkbook(bytes, existingCodes: store.codes);
    if (!context.mounted) return;
    final eggs = result.lots.fold(0, (s, l) => s + l.eggsSet);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Importer les lots ?'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${result.lots.length} lot(s) trouvés · ${formatInt(eggs)} œufs.'),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Lignes non reprises :', style: TextStyle(fontWeight: FontWeight.w700)),
              for (final w in result.warnings) Text('• $w'),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(
              onPressed: result.lots.isEmpty ? null : () => Navigator.pop(c, true), child: const Text('Importer')),
        ],
      ),
    );
    if (ok != true) return;
    await store.addIncubationLots(result.lots);
    if (context.mounted) showInfo(context, '${result.lots.length} lot(s) importé(s).');
  }
}

Future<void> openIncubationLot(BuildContext context, LotStore store, IncubationLot lot, DateTime today) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => IncubationLotDetailScreen(store: store, lot: lot, today: today)));

class IncubationLotTile extends StatelessWidget {
  const IncubationLotTile({super.key, required this.lot, required this.today, required this.onTap});
  final IncubationLot lot;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = lot.statusAt(today);
    final detail = lot.hasResult
        ? '${formatInt(lot.hatched!)} éclos sur ${formatInt(lot.eggsSet)} · ${formatPercent(lot.hatchRate)}'
        : 'Éclosion prévue le ${formatDate(lot.schedule.hatchDate)}';
    return Card(
      child: InkWell(
        key: ValueKey('lot-${lot.code}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${lot.code} · ${lot.speciesLabel}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              StatusChip.incubation(s),
            ]),
            const SizedBox(height: 6),
            Text('${lot.ownerType.label} : ${lot.ownerName} · ${formatInt(lot.eggsSet)} œufs',
                style: const TextStyle(color: NafaColors.textMuted)),
            Text(detail, style: const TextStyle(color: NafaColors.textMuted)),
            if (lot.suspiciousMortality)
              const Text('À vérifier : mortalité égale au nombre d’éclos',
                  style: TextStyle(color: NafaColors.urgent, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class IncubationLotForm extends StatefulWidget {
  const IncubationLotForm({super.key, required this.store, required this.today});
  final LotStore store;
  final DateTime today;

  @override
  State<IncubationLotForm> createState() => _IncubationLotFormState();
}

class _IncubationLotFormState extends State<IncubationLotForm> {
  final _form = GlobalKey<FormState>();
  final _eggs = TextEditingController();
  final _owner = TextEditingController();
  final _obs = TextEditingController();
  late final _days = TextEditingController(text: '${_profile.incubationDays}');
  late final _descente = TextEditingController(text: '${_profile.descenteDay}');
  SpeciesProfile _profile = defaultSpeciesProfiles.first;
  OwnerType _ownerType = OwnerType.producteur;
  late DateTime _date = widget.today;

  @override
  void dispose() {
    for (final c in [_eggs, _owner, _obs, _days, _descente]) {
      c.dispose();
    }
    super.dispose();
  }

  IncubationSchedule? get _preview {
    final d = int.tryParse(_days.text);
    final s = int.tryParse(_descente.text);
    if (d == null || s == null) return null;
    try {
      return IncubationSchedule(entryDate: _date, incubationDays: d, descenteDay: s);
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      final lot = IncubationLot(
        id: widget.store.newId(),
        code: widget.store.nextIncubationCode(_ownerType, _date),
        ownerType: _ownerType,
        ownerName: _ownerType == OwnerType.producteur ? 'Producteur' : _owner.text.trim(),
        speciesLabel: _profile.label,
        entryDate: _date,
        eggsSet: int.parse(_eggs.text),
        incubationDays: int.parse(_days.text),
        descenteDay: int.parse(_descente.text),
        observations: _obs.text.trim(),
      );
      await widget.store.addIncubationLot(lot);
      if (mounted) {
        Navigator.of(context).pop();
        showInfo(context, 'Lot ${lot.code} créé. Descente le ${formatDate(lot.schedule.descenteDate)}, '
            'éclosion le ${formatDate(lot.schedule.hatchDate)}.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Mettre des œufs en couveuse')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InfoRow('Code attribué automatiquement', widget.store.nextIncubationCode(_ownerType, _date)),
            const SizedBox(height: 8),
            SegmentedButton<OwnerType>(
              segments: [for (final o in OwnerType.values) ButtonSegment(value: o, label: Text(o.label))],
              selected: {_ownerType},
              onSelectionChanged: (s) => setState(() => _ownerType = s.first),
            ),
            if (_ownerType == OwnerType.client) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('client'),
                controller: _owner,
                decoration: const InputDecoration(labelText: 'Nom du client', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire pour un client' : null,
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<SpeciesProfile>(
              initialValue: _profile,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Espèce ou race', border: OutlineInputBorder()),
              items: [
                for (final p in defaultSpeciesProfiles)
                  DropdownMenuItem(value: p, child: Text('${p.label} · ${p.incubationDays} jours', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (p) => setState(() {
                _profile = p ?? _profile;
                _days.text = '${_profile.incubationDays}';
                _descente.text = '${_profile.descenteDay}';
              }),
            ),
            const SizedBox(height: 12),
            DateField(label: 'Date de mise en couveuse', value: _date, onChanged: (d) => setState(() => _date = d)),
            const SizedBox(height: 12),
            IntField(key: const ValueKey('oeufs'), controller: _eggs, label: 'Nombre d’œufs', suffix: 'œufs', min: 1),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: IntField(controller: _days, label: 'Durée', suffix: 'jours', min: 1)),
              const SizedBox(width: 12),
              Expanded(child: IntField(controller: _descente, label: 'Jour de descente', min: 1)),
            ]),
            const SizedBox(height: 12),
            Card(
              color: NafaColors.greenLight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: preview == null
                    ? const Text('Le jour de descente doit être plus petit que la durée.',
                        style: TextStyle(color: NafaColors.urgent))
                    : Column(children: [
                        InfoRow('Descente des œufs', '${formatDate(preview.descenteDate)} · jour ${preview.descenteDay}'),
                        InfoRow('Éclosion prévue', '${formatDate(preview.hatchDate)} · jour ${preview.incubationDays}'),
                      ]),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _obs,
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

class IncubationLotDetailScreen extends StatelessWidget {
  const IncubationLotDetailScreen({super.key, required this.store, required this.lot, required this.today});
  final LotStore store;
  final IncubationLot lot;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = lot.schedule;
        final day = s.dayAt(today);
        return Scaffold(
          appBar: AppBar(title: Text(lot.code)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(title: lot.speciesLabel, trailing: StatusChip.incubation(lot.statusAt(today)), children: [
                InfoRow('Propriétaire', '${lot.ownerType.label} · ${lot.ownerName}'),
                InfoRow('Œufs mis', '${formatInt(lot.eggsSet)} œufs'),
                InfoRow('Mise en couveuse', formatDate(lot.entryDate)),
                InfoRow('Descente des œufs', '${formatDate(s.descenteDate)} · jour ${s.descenteDay}'),
                InfoRow('Éclosion prévue', '${formatDate(s.hatchDate)} · jour ${s.incubationDays}'),
                if (!lot.hasResult && day >= 0 && day <= s.incubationDays)
                  InfoRow('Aujourd’hui', 'jour $day sur ${s.incubationDays}'),
              ]),
              const SizedBox(height: 12),
              SectionCard(title: 'Résultat de l’éclosion', children: [
                if (!lot.hasResult)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Pas encore saisi.', style: TextStyle(color: NafaColors.textMuted)),
                  )
                else ...[
                  InfoRow('Poussins éclos', formatInt(lot.hatched!)),
                  InfoRow('Œufs non éclos', formatInt(lot.unhatched!)),
                  InfoRow('Taux d’éclosion', formatPercent(lot.hatchRate)),
                  InfoRow('Mortalité à l’éclosion', formatInt(lot.chickDeaths ?? 0),
                      valueColor: lot.suspiciousMortality ? NafaColors.urgent : null),
                  InfoRow('Poussins vivants', formatInt(lot.alive!)),
                  if (lot.suspiciousMortality)
                    const Text('À vérifier : tous les poussins éclos sont notés morts.',
                        style: TextStyle(color: NafaColors.urgent, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('saisir-eclosion'),
                  onPressed: () => _hatchDialog(context),
                  icon: const Icon(Icons.egg_alt_outlined),
                  label: Text(lot.hasResult ? 'Corriger le résultat' : 'Enregistrer l’éclosion'),
                ),
              ]),
              if (lot.observations.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionCard(title: 'Observations', children: [Text(lot.observations)]),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _hatchDialog(BuildContext context) async {
    final hatched = TextEditingController(text: lot.hatched?.toString() ?? '');
    final deaths = TextEditingController(text: lot.chickDeaths?.toString() ?? '');
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Résultat de l’éclosion'),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            IntField(key: const ValueKey('eclos'), controller: hatched, label: 'Poussins éclos', max: lot.eggsSet),
            const SizedBox(height: 12),
            IntField(key: const ValueKey('morts'), controller: deaths, label: 'Poussins morts à l’éclosion', optional: true),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(
            key: const ValueKey('valider-eclosion'),
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                lot.recordHatch(
                  hatched: int.parse(hatched.text),
                  chickDeaths: deaths.text.isEmpty ? null : int.parse(deaths.text),
                );
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
    );
  }
}
