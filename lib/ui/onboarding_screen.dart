import 'package:material_ui/material_ui.dart';

import '../data/app_data.dart';
import '../data/onboarding_plan.dart';
import '../domain/farm.dart';
import '../domain/feed.dart';
import '../domain/finance.dart';
import '../domain/format.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';

enum _Step { production, ferme, race, lot, aliment, prix, utilisateurs }

/// Assistant de démarrage : la première question est la production
/// (master prompt), puis les étapes du dossier (ferme, race, premier lot,
/// aliment, prix, utilisateurs). Chaque étape après la production peut
/// être passée ; tout se règle aussi plus tard dans Paramètres.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.data, this.today});
  final AppData data;
  final DateTime? today;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _plan = OnboardingPlan();
  final _form = GlobalKey<FormState>();
  var _index = 0;
  bool _saving = false;

  late final DateTime _today = widget.today ?? DateTime.now();
  final _farmName = TextEditingController();
  final _location = TextEditingController();
  final _breed = TextEditingController();
  final _count = TextEditingController();
  final _feedName = TextEditingController();
  final _bagKg = TextEditingController(text: '50');
  final _bags = TextEditingController();
  final _bagPrice = TextEditingController();
  final Map<SaleCategory, TextEditingController> _prices = {};
  final _userName = TextEditingController();
  late DateTime _lotDate = _today;
  bool _withLot = true;
  bool _withFeed = true;
  LotObjective _objective = LotObjective.engraissement;
  FeedStage _stage = FeedStage.demarrage;
  UserRole _role = UserRole.proprietaire;

  ProductionType? get _p => _plan.production;

  List<_Step> get _steps => [
        _Step.production,
        _Step.ferme,
        _Step.race,
        if (_p != ProductionType.couveuse) ...[_Step.lot, _Step.aliment],
        _Step.prix,
        _Step.utilisateurs,
      ];

  _Step get _step => _steps[_index];
  bool get _last => _index == _steps.length - 1;

  @override
  void dispose() {
    for (final c in [_farmName, _location, _breed, _count, _feedName, _bagKg, _bags, _bagPrice, _userName, ..._prices.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next({bool skip = false}) {
    if (!skip && !(_form.currentState?.validate() ?? true)) return;
    _collect(skip: skip);
    if (_last) {
      _finish();
    } else {
      setState(() => _index++);
    }
  }

  /// Recopie les réponses de l'étape dans le plan.
  void _collect({required bool skip}) {
    switch (_step) {
      case _Step.production:
        break;
      case _Step.ferme:
        _plan
          ..farmName = skip ? '' : _farmName.text
          ..location = skip ? '' : _location.text;
      case _Step.race:
        _plan.breed = skip || _breed.text.trim().isEmpty ? null : _breed.text.trim();
        if (_p == ProductionType.couveuse && !skip) _plan.breed = _speciesId;
      case _Step.lot:
        _plan.lot = skip || !_withLot || _plan.breed == null
            ? null
            : FirstLot(startDate: _lotDate, count: int.parse(_count.text), objective: _objective);
        _stage = OnboardingPlan.suggestedStage(_p!, _objective);
      case _Step.aliment:
        _plan.feed = skip || !_withFeed || _feedName.text.trim().isEmpty
            ? null
            : FirstFeed(
                name: _feedName.text.trim(),
                stage: _stage,
                kgPerBag: int.tryParse(_bagKg.text) ?? 50,
                bags: int.tryParse(_bags.text) ?? 0,
                pricePerBag: int.tryParse(_bagPrice.text) ?? 0,
              );
      case _Step.prix:
        _plan.prices.clear();
        if (!skip) {
          for (final e in _prices.entries) {
            final v = int.tryParse(e.value.text);
            if (v != null && v > 0) _plan.prices[e.key] = v;
          }
        }
      case _Step.utilisateurs:
        if (skip) {
          _plan.users.clear();
        } else if (_userName.text.trim().isNotEmpty) {
          // Nom saisi sans appuyer sur « Ajouter » : on l'ajoute quand même.
          _plan.users.add(FarmUser(_userName.text.trim(), _role));
          _userName.clear();
        }
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await _plan.apply(widget.data, _today);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, e);
      }
    }
  }

  String? _speciesId;

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  Image.asset('assets/images/nafa_logo.png',
                      height: 56, alignment: Alignment.centerLeft, semanticLabel: 'Nafa Élevage'),
                  const SizedBox(height: 16),
                  if (_index > 0) ...[
                    Text('ÉTAPE ${_index + 1} SUR ${steps.length}',
                        style: const TextStyle(color: NafaColors.green, fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 12)),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: (_index + 1) / steps.length, color: NafaColors.green),
                    const SizedBox(height: 16),
                  ],
                  ..._content(),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: ValueKey(_last ? 'terminer' : 'continuer'),
                    onPressed: _saving || _p == null ? null : _next,
                    child: Text(_last ? 'Terminer' : 'Continuer'),
                  ),
                  if (_index > 0)
                    Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, children: [
                      TextButton(
                        key: const ValueKey('retour'),
                        onPressed: _saving ? null : () => setState(() => _index--),
                        child: const Text('Retour'),
                      ),
                      TextButton(
                        key: const ValueKey('passer'),
                        onPressed: _saving ? null : () => _next(skip: true),
                        child: Text(_last ? 'Passer et terminer' : 'Passer cette étape'),
                      ),
                    ]),
                  if (_index > 0) ...[
                    const SizedBox(height: 12),
                    const Text('Vous pourrez tout modifier plus tard dans Paramètres.',
                        textAlign: TextAlign.center, style: TextStyle(color: NafaColors.textMuted, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String t, [String? sub]) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2)),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(color: NafaColors.textMuted, fontSize: 15)),
        ],
        const SizedBox(height: 16),
      ]);

  List<Widget> _content() {
    final cfg = widget.data.config;
    switch (_step) {
      case _Step.production:
        final options = _p == null ? const <OptionalFeature>[] : optionsFor(_p!);
        return [
          const Text('BIENVENUE DANS NAFA ÉLEVAGE',
              style: TextStyle(color: NafaColors.green, fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 8),
          _title('Quelle production voulez-vous gérer ?', 'Nafa affichera seulement les écrans utiles.'),
          for (final p in ProductionType.values) ...[
            _ProductionTile(
              production: p,
              selected: _p == p,
              onTap: () => setState(() {
                _plan.production = p;
                _plan.options.removeWhere((o) => !optionsFor(p).contains(o));
                _breed.clear();
              }),
            ),
            const SizedBox(height: 10),
          ],
          for (final o in options)
            Card(
              color: NafaColors.greenLight,
              child: CheckboxListTile(
                key: ValueKey('option-${o.name}'),
                value: _plan.options.contains(o),
                onChanged: (v) => setState(() => v == true ? _plan.options.add(o) : _plan.options.remove(o)),
                title: Text(optionLabel(o), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(optionHelp(o)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
        ];

      case _Step.ferme:
        return [
          _title('Votre ferme', 'Son nom apparaîtra sur l’écran d’accueil et dans les rapports.'),
          TextFormField(
            key: const ValueKey('nom-ferme'),
            controller: _farmName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom de la ferme (ex. Ferme de Kati)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('lieu-ferme'),
            controller: _location,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Ville ou village', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          const InfoRow('Devise', 'Franc CFA (FCFA)'),
        ];

      case _Step.race:
        if (_p == ProductionType.couveuse) {
          _speciesId ??= cfg.species.first.id;
          return [
            _title('Quelle espèce couvez-vous le plus ?', 'Elle sera proposée en premier pour chaque lot d’œufs.'),
            RadioGroup<String>(
              groupValue: _speciesId,
              onChanged: (v) => setState(() => _speciesId = v),
              child: Column(children: [
                for (final s in cfg.species)
                  RadioListTile<String>(
                    key: ValueKey('espece-${s.id}'),
                    value: s.id,
                    title: Text(s.label),
                    subtitle: Text('${s.incubationDays} jours · descente au jour ${s.descenteDay}'),
                  ),
              ]),
            ),
          ];
        }
        return [
          _title('Quelle race élevez-vous ?', 'Choisissez dans la liste ou écrivez le nom.'),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final b in cfg.breedsFor(_p!))
              ChoiceChip(label: Text(b), selected: _breed.text == b, onSelected: (_) => setState(() => _breed.text = b)),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('race'),
            controller: _breed,
            decoration: const InputDecoration(labelText: 'Autre race ou souche', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
        ];

      case _Step.lot:
        return [
          _title('Votre premier lot', 'L’âge se calculera tout seul à partir de la date.'),
          if (_plan.breed == null)
            const Text('Indiquez d’abord la race à l’étape précédente, ou passez cette étape.',
                style: TextStyle(color: NafaColors.watch))
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _withLot,
              onChanged: (v) => setState(() => _withLot = v),
              title: Text('Créer maintenant un lot de ${_plan.breed}'),
            ),
            if (_withLot) ...[
              if (_p == ProductionType.ameliorees) ...[
                const Text('Objectif du lot', style: TextStyle(fontWeight: FontWeight.w600)),
                RadioGroup<LotObjective>(
                  groupValue: _objective,
                  onChanged: (v) => setState(() => _objective = v ?? _objective),
                  child: Column(children: [
                    for (final o in LotObjective.values)
                      RadioListTile<LotObjective>(value: o, title: Text(o.label), contentPadding: EdgeInsets.zero),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              DateField(label: 'Date de démarrage', value: _lotDate, last: _today, onChanged: (d) => setState(() => _lotDate = d)),
              const SizedBox(height: 12),
              IntField(key: const ValueKey('effectif-depart'), controller: _count, label: 'Nombre de sujets au départ', suffix: 'sujets', min: 1),
            ],
          ],
        ];

      case _Step.aliment:
        if (_feedName.text.isEmpty) _feedName.text = 'Aliment ${_stage.label.toLowerCase()}';
        return [
          _title('Votre aliment', 'Pour suivre le stock et le coût de l’alimentation.'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _withFeed,
            onChanged: (v) => setState(() => _withFeed = v),
            title: const Text('Ajouter un aliment maintenant'),
          ),
          if (_withFeed) ...[
            TextFormField(
              key: const ValueKey('nom-aliment'),
              controller: _feedName,
              decoration: const InputDecoration(labelText: 'Nom de l’aliment', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FeedStage>(
              initialValue: _stage,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Stade', border: OutlineInputBorder()),
              items: [for (final s in FeedStage.values) DropdownMenuItem(value: s, child: Text(s.label))],
              onChanged: (v) => setState(() => _stage = v ?? _stage),
            ),
            const SizedBox(height: 12),
            IntField(controller: _bagKg, label: 'Poids d’un sac', suffix: 'kg', min: 1),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: IntField(
                      key: const ValueKey('sacs-stock'), controller: _bags, label: 'Sacs en stock', optional: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: IntField(
                      key: const ValueKey('prix-sac'), controller: _bagPrice, label: 'Prix d’un sac', suffix: 'FCFA', optional: true)),
            ]),
          ],
        ];

      case _Step.prix:
        final cats = saleCategoriesFor(_p!, _plan.options).where((c) => c != SaleCategory.autre).toList();
        for (final c in cats) {
          _prices.putIfAbsent(c, () => TextEditingController(text: widget.data.config.priceFor(c)?.toString() ?? ''));
        }
        return [
          _title('Vos prix de vente', 'Ils seront proposés à chaque vente. Vous pourrez toujours vendre à un autre prix.'),
          for (final c in cats) ...[
            IntField(
              key: ValueKey('prix-${c.name}'),
              controller: _prices[c]!,
              label: '${c.label} (par ${c.unit})',
              suffix: 'FCFA',
              optional: true,
            ),
            const SizedBox(height: 12),
          ],
        ];

      case _Step.utilisateurs:
        return [
          _title('Qui travaille sur la ferme ?', 'Indiquez au moins le propriétaire. Les droits d’accès par rôle arriveront avec la synchronisation.'),
          for (final (i, u) in _plan.users.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(u.name),
              subtitle: Text('${u.role.label} · ${u.role.rights}'),
              trailing: IconButton(
                tooltip: 'Retirer',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _plan.users.removeAt(i)),
              ),
            ),
          TextField(
            key: const ValueKey('nom-utilisateur'),
            controller: _userName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<UserRole>(
            initialValue: _role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Rôle', border: OutlineInputBorder()),
            items: [for (final r in UserRole.values) DropdownMenuItem(value: r, child: Text(r.label))],
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('ajouter-utilisateur'),
              onPressed: () {
                try {
                  setState(() {
                    _plan.users.add(FarmUser(_userName.text.trim(), _role));
                    _userName.clear();
                    if (_role == UserRole.proprietaire) _role = UserRole.employe;
                  });
                } catch (e) {
                  showError(context, e);
                }
              },
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Ajouter cette personne'),
            ),
          ),
          if (_plan.lot != null || _plan.feed != null || _plan.prices.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(title: 'Ce qui sera créé', children: [
              if (_plan.lot != null)
                InfoRow('Premier lot', '${_plan.breed} · ${formatInt(_plan.lot!.count)} sujets'),
              if (_plan.feed != null)
                InfoRow('Aliment', '${_plan.feed!.name}${_plan.feed!.bags > 0 ? ' · ${formatInt(_plan.feed!.bags)} sac(s)' : ''}'),
              if (_plan.prices.isNotEmpty) InfoRow('Prix de vente', '${_plan.prices.length} prix'),
            ]),
          ],
        ];
    }
  }
}

class _ProductionTile extends StatelessWidget {
  const _ProductionTile({required this.production, required this.selected, required this.onTap});
  final ProductionType production;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? NafaColors.greenLight : NafaColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? NafaColors.green : NafaColors.border, width: selected ? 2 : 1),
        ),
        child: InkWell(
          key: ValueKey('production-${production.name}'),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: selected ? NafaColors.green : NafaColors.greenLight,
                  foregroundColor: selected ? Colors.white : NafaColors.green,
                  child: Icon(productionIcon(production)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(production.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(production.description, style: const TextStyle(color: NafaColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(selected ? Icons.check_circle : Icons.chevron_right,
                    color: selected ? NafaColors.green : NafaColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
