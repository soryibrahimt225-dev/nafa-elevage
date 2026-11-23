import 'package:material_ui/material_ui.dart';

import '../data/app_data.dart';
import '../domain/feed.dart';
import '../domain/finance.dart';
import '../domain/format.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import 'theme.dart';
import 'widgets.dart';

/// Alimentation : catalogue, stock, achats, distribution aux lots, pertes,
/// consommation et coût alimentaire. Les rations restent à valider par un
/// technicien en nutrition animale.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key, required this.data, required this.today});
  final AppData data;
  final DateTime today;

  ProductionType get _production => data.settings.production!;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([data.feed, data.lots, data.eggs]),
        builder: (context, _) {
          final feed = data.feed;
          final stocks = feed.stocks;
          final lots = data.lots.animalLots(_production).where((l) => l.status == LotStatus.enCours).toList();
          final lowCount = stocks.values.where((s) => s.low).length;
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              key: const ValueKey('nouvel-aliment'),
              onPressed: () => _itemDialog(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un aliment'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                const Text('Alimentation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  lowCount > 0 ? '$lowCount aliment(s) sous le seuil d’alerte' : 'Stock, distribution et coût de l’aliment',
                  style: TextStyle(color: lowCount > 0 ? NafaColors.urgent : NafaColors.textMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (feed.items.isEmpty)
                  const EmptyState(
                    icon: Icons.grass_outlined,
                    title: 'Aucun aliment',
                    message: 'Ajoutez vos aliments (démarrage, finition, pondeuse…) puis enregistrez vos achats en sacs.',
                  ),
                for (final i in feed.items) ...[
                  _StockCard(screen: this, stock: stocks[i.id]!, lots: lots),
                  const SizedBox(height: 8),
                ],
                if (lots.isNotEmpty && feed.items.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _ConsumptionCard(screen: this, lots: lots),
                ],
                if (feed.moves.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _HistoryCard(screen: this),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Les rations et formules doivent être validées par un technicien en nutrition animale. '
                  'Nafa calcule les quantités et les coûts à partir de vos saisies.',
                  style: TextStyle(color: NafaColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          );
        },
      );

  Future<void> _itemDialog(BuildContext context, FeedItem? item) async {
    final name = TextEditingController(text: item?.name ?? '');
    final bag = TextEditingController(text: '${item?.kgPerBag ?? 50}');
    final bagPrice = TextEditingController(text: item?.bagPrice?.toString() ?? '');
    final alert = TextEditingController(text: item?.alertKg?.toString() ?? '');
    final supplier = TextEditingController(text: item?.supplier ?? '');
    var stage = item?.stage ?? FeedStage.demarrage;
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: Text(item == null ? 'Nouvel aliment' : item.name),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  key: const ValueKey('nom-aliment'),
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nom (ex. Aliment démarrage)', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FeedStage>(
                  initialValue: stage,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Stade', border: OutlineInputBorder()),
                  items: [for (final s in FeedStage.values) DropdownMenuItem(value: s, child: Text(s.label))],
                  onChanged: (v) => setState(() => stage = v ?? stage),
                ),
                const SizedBox(height: 12),
                IntField(controller: bag, label: 'Poids d’un sac', suffix: 'kg', min: 1, max: 1000),
                const SizedBox(height: 12),
                IntField(key: const ValueKey('prix-du-sac'), controller: bagPrice, label: 'Prix habituel d’un sac', suffix: 'FCFA', optional: true),
                const SizedBox(height: 12),
                IntField(controller: alert, label: 'Alerte si le stock passe sous', suffix: 'kg', optional: true),
                const SizedBox(height: 12),
                TextFormField(
                  controller: supplier,
                  decoration: const InputDecoration(labelText: 'Fournisseur habituel (facultatif)', border: OutlineInputBorder()),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
            FilledButton(
              key: const ValueKey('valider-aliment'),
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                try {
                  await data.feed.saveItem(FeedItem(
                    id: item?.id ?? data.feed.newId(),
                    name: name.text.trim(),
                    stage: stage,
                    kgPerBag: int.parse(bag.text),
                    alertKg: alert.text.isEmpty ? null : int.parse(alert.text),
                    supplier: supplier.text.trim(),
                    bagPrice: int.tryParse(bagPrice.text),
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
      ),
    );
  }

  /// Achat en sacs, avec création de la dépense correspondante.
  Future<void> _purchase(BuildContext context, FeedItem item) async {
    final bags = TextEditingController();
    final price = TextEditingController(text: item.bagPrice?.toString() ?? '');
    final form = GlobalKey<FormState>();
    var withExpense = true;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) {
          final n = int.tryParse(bags.text) ?? 0, p = int.tryParse(price.text) ?? 0;
          return AlertDialog(
            title: Text('Achat · ${item.name}'),
            content: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  IntField(
                      key: const ValueKey('sacs'),
                      controller: bags,
                      label: 'Nombre de sacs de ${item.kgPerBag} kg',
                      min: 1,
                      onChanged: (_) => setState(() {})),
                  const SizedBox(height: 12),
                  IntField(
                      key: const ValueKey('prix-sac'),
                      controller: price,
                      label: 'Prix d’un sac',
                      suffix: 'FCFA',
                      onChanged: (_) => setState(() {})),
                  const SizedBox(height: 12),
                  InfoRow('Quantité', formatKg(n * item.kgPerBag * 1000)),
                  InfoRow('Montant', formatFcfa(n * p)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: withExpense,
                    onChanged: (v) => setState(() => withExpense = v),
                    title: const Text('Enregistrer aussi la dépense'),
                    subtitle: const Text('Catégorie « Aliment », payée en totalité.'),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
              FilledButton(
                key: const ValueKey('valider-achat'),
                onPressed: () async {
                  if (!form.currentState!.validate()) return;
                  final count = int.parse(bags.text), unit = int.parse(price.text);
                  try {
                    String? expenseId;
                    if (withExpense) {
                      final e = Expense(
                        id: data.finance.newId(),
                        date: today,
                        category: ExpenseCategory.aliment,
                        quantity: count,
                        unitPrice: unit,
                        amountPaid: count * unit,
                        production: _production,
                        supplier: item.supplier,
                        description: '${item.name} · $count sac(s) de ${item.kgPerBag} kg',
                      );
                      await data.finance.addExpense(e);
                      expenseId = e.id;
                    }
                    await data.feed.addMove(FeedMove(
                      id: data.feed.newId(),
                      itemId: item.id,
                      date: today,
                      type: FeedMoveType.achat,
                      grams: count * item.kgPerBag * 1000,
                      cost: count * unit,
                      expenseId: expenseId,
                    ));
                    if (d.mounted) Navigator.pop(d);
                  } catch (e) {
                    if (d.mounted) showError(d, e);
                  }
                },
                child: const Text('Enregistrer l’achat'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Distribution à un lot (ou perte), avec calcul de la ration :
  /// effectif × grammes par sujet.
  Future<void> distribute(BuildContext context, FeedItem item, List<AnimalLot> lots, {required bool loss}) async {
    final kg = TextEditingController();
    final perSubject = TextEditingController();
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    String? lotCode = lots.isEmpty ? null : lots.first.code;
    var date = today;
    final left = data.feed.stockOf(item.id).remainingGrams;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) {
          final lot = lots.where((l) => l.code == lotCode).firstOrNull;
          return AlertDialog(
            title: Text(loss ? 'Perte · ${item.name}' : 'Distribuer · ${item.name}'),
            content: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Text('Stock : ${formatKg(left)}', style: const TextStyle(color: NafaColors.textMuted)),
                  const SizedBox(height: 12),
                  if (!loss) ...[
                    DropdownButtonFormField<String>(
                      initialValue: lotCode,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Lot', border: OutlineInputBorder()),
                      items: [
                        for (final l in lots)
                          DropdownMenuItem(
                              value: l.code,
                              child: Text('${l.code} · ${formatInt(l.current)} sujets', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => lotCode = v),
                    ),
                    const SizedBox(height: 12),
                    // Ration : effectif × grammes par sujet ÷ 1 000.
                    IntField(
                      key: const ValueKey('g-par-sujet'),
                      controller: perSubject,
                      label: 'Ration par sujet (facultatif)',
                      suffix: 'g',
                      optional: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (lot != null && (int.tryParse(perSubject.text) ?? 0) > 0)
                      TextButton(
                        onPressed: () => setState(() {
                          final g = rationGrams(lot.current, int.parse(perSubject.text));
                          kg.text = (g / 1000).toStringAsFixed(1).replaceAll('.', ',');
                        }),
                        child: Text('Calculer : ${formatInt(lot.current)} × ${perSubject.text} g = '
                            '${formatKg(rationGrams(lot.current, int.parse(perSubject.text)))}'),
                      ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    key: const ValueKey('kg'),
                    controller: kg,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantité', suffixText: 'kg', border: OutlineInputBorder()),
                    validator: (v) {
                      final g = parseKg(v ?? '');
                      if (g == null || g <= 0) return 'Quantité en kg (ex. 12,5)';
                      if (g > left) return 'Stock insuffisant : ${formatKg(left)}';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DateField(label: 'Date', value: date, last: today, onChanged: (v) => setState(() => date = v)),
                  if (loss) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: note,
                      decoration: const InputDecoration(labelText: 'Cause (humidité, moisissure…)', border: OutlineInputBorder()),
                    ),
                  ],
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
              FilledButton(
                key: const ValueKey('valider-distribution'),
                onPressed: () async {
                  if (!form.currentState!.validate()) return;
                  try {
                    await data.feed.addMove(FeedMove(
                      id: data.feed.newId(),
                      itemId: item.id,
                      date: date,
                      type: loss ? FeedMoveType.perte : FeedMoveType.distribution,
                      grams: parseKg(kg.text)!,
                      lotCode: loss ? null : lotCode,
                      note: note.text.trim(),
                    ));
                    if (d.mounted) Navigator.pop(d);
                  } catch (e) {
                    if (d.mounted) showError(d, e);
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.screen, required this.stock, required this.lots});
  final FeedScreen screen;
  final FeedStock stock;
  final List<AnimalLot> lots;

  @override
  Widget build(BuildContext context) {
    final i = stock.item;
    final bags = stock.remainingGrams / (i.kgPerBag * 1000);
    return SectionCard(
      title: i.name,
      trailing: stock.low
          ? const StatusChip('Stock bas', NafaColors.urgent)
          : StatusChip(i.stage.label, NafaColors.done),
      children: [
        if (i.bagPrice != null) InfoRow('Prix du sac de ${i.kgPerBag} kg', formatFcfa(i.bagPrice!)),
        InfoRow('Stock restant',
            '${formatKg(stock.remainingGrams)} · ${bags.toStringAsFixed(1).replaceAll('.', ',')} sac(s)',
            valueColor: stock.low ? NafaColors.urgent : null),
        if (stock.costPerKg != null) ...[
          InfoRow('Coût moyen', '${formatFcfa(stock.costPerKg!.round())} par kg'),
          InfoRow('Valeur du stock', formatFcfa(stock.value)),
        ],
        InfoRow('Distribué', formatKg(stock.distributedGrams)),
        if (stock.lostGrams > 0) InfoRow('Pertes', formatKg(stock.lostGrams)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            key: ValueKey('achat-${i.name}'),
            onPressed: () => screen._purchase(context, i),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Achat'),
          ),
          OutlinedButton.icon(
            key: ValueKey('distribuer-${i.name}'),
            onPressed: stock.remainingGrams <= 0 || lots.isEmpty
                ? null
                : () => screen.distribute(context, i, lots, loss: false),
            icon: const Icon(Icons.grass_outlined),
            label: const Text('Distribuer'),
          ),
          TextButton(
            onPressed: stock.remainingGrams <= 0 ? null : () => screen.distribute(context, i, lots, loss: true),
            child: const Text('Perte'),
          ),
          TextButton(onPressed: () => screen._itemDialog(context, i), child: const Text('Modifier')),
        ]),
      ],
    );
  }
}

class _ConsumptionCard extends StatelessWidget {
  const _ConsumptionCard({required this.screen, required this.lots});
  final FeedScreen screen;
  final List<AnimalLot> lots;

  @override
  Widget build(BuildContext context) {
    final today = screen.today;
    return SectionCard(title: 'Consommation par lot', children: [
      for (final l in lots) ...[
        Builder(builder: (context) {
          final f = screen.data.feed.forLot(l.code);
          // Moyenne depuis la première distribution saisie (et non depuis la
          // naissance du lot), avec l'effectif de ce jour-là et d'aujourd'hui.
          final first = f.firstDate;
          final days = first == null ? 0 : ageInDays(first, today) + 1;
          final avgSubjects = first == null ? 0 : ((l.countAt(first) + l.current) / 2).round();
          final perDay = f.gramsPerSubjectPerDay(subjects: avgSubjects, days: days);
          final lines = <String>[
            '${formatKg(f.grams)} · ${formatFcfa(f.costFcfa)}',
            if (perDay != null && f.grams > 0)
              'environ ${perDay.round()} g par sujet et par jour depuis le ${formatDate(first!)}',
            if (l.current > 0 && f.grams > 0) '${formatFcfa((f.cost / l.current).round())} par sujet présent',
          ];
          if (screen._production == ProductionType.pondeuses || l.objective == LotObjective.ponte) {
            final eggs = screen.data.eggs.forLots({l.code}).fold(0, (n, r) => n + r.table);
            if (eggs > 0) lines.add('${formatFcfa((f.cost / eggs).round())} par œuf de table');
          }
          return InfoRow('${l.code} · ${l.breed}', lines.join('\n'));
        }),
        if (screen.data.feed.forLot(l.code).unpricedGrams > 0)
          const Text('Coût incomplet : aliment distribué sans prix d’achat.',
              style: TextStyle(color: NafaColors.watch, fontSize: 12)),
      ],
    ]);
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.screen});
  final FeedScreen screen;

  @override
  Widget build(BuildContext context) {
    final feed = screen.data.feed;
    final names = {for (final i in feed.items) i.id: i.name};
    return SectionCard(title: 'Derniers mouvements', children: [
      for (final m in feed.moves.take(12))
        InkWell(
          onLongPress: () async {
            try {
              final expenseId = await feed.deleteMove(m.id);
              if (expenseId != null) await screen.data.finance.deleteExpense(expenseId);
              if (context.mounted) showInfo(context, 'Mouvement supprimé.');
            } catch (e) {
              if (context.mounted) showError(context, e);
            }
          },
          child: InfoRow(
            '${formatDate(m.date)} · ${m.type.label} · ${names[m.itemId] ?? ''}${m.lotCode == null ? '' : ' · ${m.lotCode}'}',
            m.type == FeedMoveType.achat ? '+ ${formatKg(m.grams)}' : '− ${formatKg(m.grams)}',
          ),
        ),
      const Text('Appui long sur une ligne pour la supprimer.', style: TextStyle(color: NafaColors.textMuted, fontSize: 12)),
    ]);
  }
}
