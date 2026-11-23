import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/config_store.dart';
import '../data/settings_store.dart';
import '../domain/config.dart';
import '../domain/finance.dart';
import '../domain/format.dart';
import '../domain/incubation.dart';
import '../domain/production.dart';
import 'config_scope.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});
  final FarmSettings settings;

  bool get _incubation =>
      settings.production == ProductionType.couveuse ||
      settings.options.contains(OptionalFeature.couvaisonConversion) ||
      settings.options.contains(OptionalFeature.couveusePondeuses);

  @override
  Widget build(BuildContext context) {
    final p = settings.production!;
    final config = ConfigScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Paramètres', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        SectionCard(title: 'Production', children: [
          InfoRow('Production gérée', p.label),
          for (final o in optionsFor(p))
            SwitchListTile(
              key: ValueKey('switch-${o.name}'),
              contentPadding: EdgeInsets.zero,
              value: settings.options.contains(o),
              onChanged: (v) => settings.setOption(o, v),
              title: Text(optionLabel(o)),
              subtitle: Text(optionHelp(o)),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Changer de production'),
            onPressed: () async {
              final ok = await _confirm(context, 'Changer de production ?',
                  'Vous reviendrez à l’écran de choix. Aucune donnée n’est supprimée.');
              if (ok) await settings.reset();
            },
          ),
        ]),
        if (_incubation) ...[
          const SizedBox(height: 12),
          _SpeciesSection(config: config),
        ],
        if (p != ProductionType.couveuse) ...[
          const SizedBox(height: 12),
          _BreedsSection(config: config, production: p),
        ],
        if (p == ProductionType.ameliorees) ...[
          const SizedBox(height: 12),
          _CycleSection(config: config),
        ],
        const SizedBox(height: 12),
        _PricesSection(config: config, categories: saleCategoriesFor(p, settings.options)),
      ],
    );
  }
}

class _SpeciesSection extends StatelessWidget {
  const _SpeciesSection({required this.config});
  final ConfigStore config;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Espèces de couvaison',
        trailing: IconButton(
          tooltip: 'Ajouter une espèce',
          icon: const Icon(Icons.add),
          onPressed: () => _edit(context, null),
        ),
        children: [
          const Text('Durée d’incubation et jour de descente (arrêt du retournement), selon votre méthode.',
              style: TextStyle(color: NafaColors.textMuted, fontSize: 13)),
          for (final s in config.species)
            ListTile(
              key: ValueKey('espece-${s.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${s.incubationDays} jours · descente au jour ${s.descenteDay}'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _edit(context, s),
            ),
        ],
      );

  Future<void> _edit(BuildContext context, SpeciesProfile? s) async {
    final name = TextEditingController(text: s?.label ?? '');
    final days = TextEditingController(text: '${s?.incubationDays ?? 21}');
    final descente = TextEditingController(text: '${s?.descenteDay ?? 18}');
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(s == null ? 'Nouvelle espèce' : s.label),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (s == null) ...[
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 12),
            ],
            IntField(key: const ValueKey('duree'), controller: days, label: 'Durée d’incubation', suffix: 'jours', min: 1, max: 60),
            const SizedBox(height: 12),
            IntField(key: const ValueKey('jour-descente'), controller: descente, label: 'Jour de descente', min: 1, max: 59),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(
            key: const ValueKey('valider-espece'),
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                await config.setSpecies(SpeciesProfile(
                  id: s?.id ?? 'perso-${DateTime.now().microsecondsSinceEpoch}',
                  label: s?.label ?? name.text.trim(),
                  incubationDays: int.parse(days.text),
                  descenteDay: int.parse(descente.text),
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
}

class _BreedsSection extends StatelessWidget {
  const _BreedsSection({required this.config, required this.production});
  final ConfigStore config;
  final ProductionType production;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Races et souches',
        trailing: IconButton(
          key: const ValueKey('ajouter-race'),
          tooltip: 'Ajouter une race',
          icon: const Icon(Icons.add),
          onPressed: () => _add(context),
        ),
        children: [
          const Text('Proposées en un appui à la création d’un lot.',
              style: TextStyle(color: NafaColors.textMuted, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final b in config.breedsFor(production))
              InputChip(label: Text(b), onDeleted: () => config.removeBreed(production, b)),
          ]),
        ],
      );

  Future<void> _add(BuildContext context) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Ajouter une race'),
        content: TextField(
          key: const ValueKey('nom-race'),
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom de la race', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(key: const ValueKey('valider-race'), onPressed: () => Navigator.pop(d, c.text), child: const Text('Ajouter')),
        ],
      ),
    );
    if (name == null) return;
    try {
      await config.addBreed(production, name);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _CycleSection extends StatelessWidget {
  const _CycleSection({required this.config});
  final ConfigStore config;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Cycle des races améliorées',
        children: [
          const Text(
            'Repères en mois, par race : sélection, entrée en ponte, contrôle de production, contrôle de réforme. '
            'La réforme n’est jamais automatique.',
            style: TextStyle(color: NafaColors.textMuted, fontSize: 13),
          ),
          for (final b in config.breedsFor(ProductionType.ameliorees))
            ListTile(
              key: ValueKey('cycle-$b'),
              contentPadding: EdgeInsets.zero,
              title: Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_summary(config.cycleFor(b))),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _edit(context, b),
            ),
        ],
      );

  String _summary(ImprovedCycle c) =>
      'sélection ${c.selectionMonths} mois · ponte ${c.layingStartMonths} mois · '
      'contrôle ${c.productionReviewMonths} mois · réforme ${c.reformReviewMonths} mois';

  Future<void> _edit(BuildContext context, String breed) async {
    final c = config.cycleFor(breed);
    final ctrls = [
      TextEditingController(text: '${c.selectionMonths}'),
      TextEditingController(text: '${c.layingStartMonths}'),
      TextEditingController(text: '${c.productionReviewMonths}'),
      TextEditingController(text: '${c.reformReviewMonths}'),
    ];
    const labels = ['Sélection pour la ponte', 'Entrée en ponte', 'Contrôle de production', 'Contrôle de réforme (à partir de)'];
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Cycle $breed'),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 4; i++) ...[
                IntField(controller: ctrls[i], label: labels[i], suffix: 'mois', min: 1, max: 120),
                const SizedBox(height: 10),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              final v = [for (final x in ctrls) int.parse(x.text)];
              try {
                await config.setCycle(
                    breed,
                    ImprovedCycle(
                        selectionMonths: v[0], layingStartMonths: v[1], productionReviewMonths: v[2], reformReviewMonths: v[3]));
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
}

class _PricesSection extends StatelessWidget {
  const _PricesSection({required this.config, required this.categories});
  final ConfigStore config;
  final List<SaleCategory> categories;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Prix de référence',
        children: [
          const Text('Proposés à chaque vente ; vous pouvez toujours vendre à un autre prix.',
              style: TextStyle(color: NafaColors.textMuted, fontSize: 13)),
          for (final c in categories)
            ListTile(
              key: ValueKey('prix-${c.name}'),
              contentPadding: EdgeInsets.zero,
              title: Text(c.label),
              subtitle: Text(config.priceFor(c) == null
                  ? 'Non défini'
                  : '${formatFcfa(config.priceFor(c)!)} par ${c.unit}'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _edit(context, c),
            ),
        ],
      );

  Future<void> _edit(BuildContext context, SaleCategory c) async {
    final ctrl = TextEditingController(text: config.priceFor(c)?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(c.label),
        content: TextField(
          key: const ValueKey('valeur-prix'),
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
              labelText: 'Prix par ${c.unit}', suffixText: 'FCFA', helperText: 'Laisser vide pour ne pas proposer de prix',
              border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(key: const ValueKey('valider-prix'), onPressed: () => Navigator.pop(d, ctrl.text), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (result == null) return;
    await config.setPrice(c, result.isEmpty ? null : int.parse(result));
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
