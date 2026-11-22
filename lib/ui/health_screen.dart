import 'package:material_ui/material_ui.dart';

import '../data/health_store.dart';
import '../data/lot_store.dart';
import '../domain/format.dart';
import '../domain/health.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import 'theme.dart';
import 'widgets.dart';

StatusChip healthChip(HealthStatus s) => StatusChip(s.label, switch (s) {
      HealthStatus.aVenir => NafaColors.ok,
      HealthStatus.aujourdhui => NafaColors.watch,
      HealthStatus.enRetard => NafaColors.urgent,
      HealthStatus.realise => NafaColors.done,
    });

/// Santé et vaccination (chair, races améliorées, pondeuses ; jamais la
/// couveuse). Structure de suivi seulement : aucune prescription proposée.
class HealthScreen extends StatelessWidget {
  const HealthScreen({
    super.key,
    required this.health,
    required this.lots,
    required this.production,
    required this.today,
  });
  final HealthStore health;
  final LotStore lots;
  final ProductionType production;
  final DateTime today;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([health, lots]),
        builder: (context, _) {
          final animalLots = lots.animalLots(production);
          final records = health.forLots({for (final l in animalLots) l.code}, today);
          final late = records.where((r) => r.statusAt(today) == HealthStatus.enRetard).length;
          return Scaffold(
            floatingActionButton: animalLots.isEmpty
                ? null
                : FloatingActionButton.extended(
                    key: const ValueKey('nouveau-soin'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => HealthForm(health: health, lots: animalLots, today: today))),
                    icon: const Icon(Icons.add),
                    label: const Text('Prévoir un soin'),
                  ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                const Text('Santé et vaccination', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(late > 0 ? '$late soin(s) en retard' : 'Aucun soin en retard',
                    style: TextStyle(color: late > 0 ? NafaColors.urgent : NafaColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Card(
                  color: NafaColors.greenLight,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Le programme de vaccination, les produits et les doses doivent être fixés avec votre '
                      'vétérinaire. Nafa vous aide à suivre ce qui est prévu et ce qui est fait.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (animalLots.isEmpty)
                  const EmptyState(
                    icon: Icons.medical_services_outlined,
                    title: 'Aucun lot',
                    message: 'Créez d’abord un lot dans « Lots et sujets ».',
                  )
                else if (records.isEmpty)
                  const EmptyState(
                    icon: Icons.medical_services_outlined,
                    title: 'Aucun soin prévu',
                    message: 'Ajoutez les vaccinations et traitements prévus pour vos lots.',
                  ),
                for (final r in records) ...[
                  Card(
                    child: InkWell(
                      key: ValueKey('soin-${r.id}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _detail(context, r),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text('${r.kind.label} · ${r.title}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            ),
                            healthChip(r.statusAt(today)),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            r.doneDate != null
                                ? '${r.lotCode} · réalisé le ${formatDate(r.doneDate!)}'
                                : '${r.lotCode} · prévu le ${formatDate(r.plannedDate)}'
                                    '${r.lateDays(today) > 0 ? ' (${r.lateDays(today)} jours de retard)' : ''}',
                            style: const TextStyle(color: NafaColors.textMuted),
                          ),
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

  Future<void> _detail(BuildContext context, HealthRecord r) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${r.kind.label} · ${r.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              InfoRow('Lot', r.lotCode),
              InfoRow('Statut', r.statusAt(today).label),
              InfoRow('Date prévue', formatDate(r.plannedDate)),
              if (r.doneDate != null) InfoRow('Date réalisée', formatDate(r.doneDate!)),
              if (r.product.isNotEmpty) InfoRow('Produit utilisé', r.product),
              if (r.dosage.isNotEmpty) InfoRow('Dosage ou remarque', r.dosage),
              if (r.responsible.isNotEmpty) InfoRow('Vétérinaire ou responsable', r.responsible),
              if (r.observation.isNotEmpty) InfoRow('Observation', r.observation),
              const SizedBox(height: 12),
              if (r.doneDate == null)
                FilledButton.icon(
                  key: const ValueKey('marquer-fait'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: sheet,
                      initialDate: today,
                      firstDate: DateTime(2020),
                      lastDate: today,
                      helpText: 'Date de réalisation',
                    );
                    if (d == null) return;
                    r.markDone(d);
                    await health.changed();
                    if (sheet.mounted) Navigator.pop(sheet);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Marquer comme réalisé'),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: NafaColors.urgent),
                onPressed: () async {
                  await health.delete(r.id);
                  if (sheet.mounted) Navigator.pop(sheet);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
              ),
            ]),
          ),
        ),
      );
}

class HealthForm extends StatefulWidget {
  const HealthForm({super.key, required this.health, required this.lots, required this.today});
  final HealthStore health;
  final List<AnimalLot> lots;
  final DateTime today;

  @override
  State<HealthForm> createState() => _HealthFormState();
}

class _HealthFormState extends State<HealthForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _product = TextEditingController();
  final _dosage = TextEditingController();
  final _responsible = TextEditingController();
  final _obs = TextEditingController();
  late String _lot = widget.lots.first.code;
  HealthKind _kind = HealthKind.vaccination;
  late DateTime _date = widget.today;
  bool _alreadyDone = false;

  @override
  void dispose() {
    for (final c in [_title, _product, _dosage, _responsible, _obs]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      final r = HealthRecord(
        id: widget.health.newId(),
        lotCode: _lot,
        kind: _kind,
        title: _title.text.trim(),
        plannedDate: _date,
        doneDate: _alreadyDone ? _date : null,
        product: _product.text.trim(),
        dosage: _dosage.text.trim(),
        responsible: _responsible.text.trim(),
        observation: _obs.text.trim(),
      );
      await widget.health.add(r);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lot = widget.lots.firstWhere((l) => l.code == _lot);
    final age = ageInDays(lot.startDate, _date);
    return Scaffold(
      appBar: AppBar(title: const Text('Prévoir un soin')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _lot,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Lot', border: OutlineInputBorder()),
              items: [
                for (final l in widget.lots)
                  DropdownMenuItem(value: l.code, child: Text('${l.code} · ${l.breed}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _lot = v ?? _lot),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final k in HealthKind.values)
                ChoiceChip(label: Text(k.label), selected: k == _kind, onSelected: (_) => setState(() => _kind = k)),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('soin-nom'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Nom du vaccin ou du soin', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            DateField(label: 'Date prévue', value: _date, first: lot.startDate, onChanged: (d) => setState(() => _date = d)),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text('Âge du lot à cette date : $age jours', style: const TextStyle(color: NafaColors.textMuted)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _alreadyDone,
              onChanged: _date.isAfter(widget.today) ? null : (v) => setState(() => _alreadyDone = v),
              title: const Text('Déjà réalisé à cette date'),
            ),
            TextFormField(
              controller: _product,
              decoration: const InputDecoration(labelText: 'Produit utilisé (facultatif)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dosage,
              decoration: const InputDecoration(labelText: 'Dosage ou remarque (facultatif)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _responsible,
              decoration: const InputDecoration(labelText: 'Vétérinaire ou responsable (facultatif)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _obs,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Observation (facultatif)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton(key: const ValueKey('enregistrer'), onPressed: _save, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}
