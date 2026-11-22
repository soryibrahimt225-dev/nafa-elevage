import 'package:material_ui/material_ui.dart';

import '../data/finance_store.dart';
import '../data/lot_store.dart';
import '../domain/finance.dart';
import '../domain/format.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import 'theme.dart';
import 'widgets.dart';

StatusChip paymentChip(PaymentStatus s) => StatusChip(s.label, switch (s) {
      PaymentStatus.paye => NafaColors.ok,
      PaymentStatus.partiel => NafaColors.watch,
      PaymentStatus.impaye => NafaColors.urgent,
    });

/// Contexte commun aux écrans financiers.
class FinanceContext {
  const FinanceContext({
    required this.finance,
    required this.lots,
    required this.production,
    required this.options,
    required this.today,
  });
  final FinanceStore finance;
  final LotStore lots;
  final ProductionType production;
  final Set<OptionalFeature> options;
  final DateTime today;
}

// ───────────────────────────── Ventes ─────────────────────────────

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key, required this.ctx});
  final FinanceContext ctx;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ctx.finance,
        builder: (context, _) {
          final sales = ctx.finance.sales;
          final t = Totals();
          sales.forEach(t.addSale);
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              key: const ValueKey('nouvelle-vente'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  fullscreenDialog: true, builder: (_) => SaleForm(ctx: ctx))),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle vente'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                const Text('Ventes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SectionCard(title: 'Depuis le début', children: [
                  InfoRow('Chiffre d’affaires', formatFcfa(t.sales)),
                  InfoRow('Encaissé', formatFcfa(t.collected)),
                  InfoRow('Reste à recouvrer', formatFcfa(t.toCollect),
                      valueColor: t.toCollect > 0 ? NafaColors.urgent : null),
                ]),
                const SizedBox(height: 12),
                if (sales.isEmpty)
                  const EmptyState(
                    icon: Icons.point_of_sale_outlined,
                    title: 'Aucune vente',
                    message: 'Enregistrez une vente : produit, quantité, prix et montant encaissé.',
                  ),
                for (final s in sales) ...[
                  _OperationTile(
                    key: ValueKey('vente-${s.id}'),
                    title: '${s.category.label} · ${formatInt(s.quantity)} × ${formatFcfa(s.unitPrice)}',
                    subtitle: [
                      formatDate(s.date),
                      if (s.client.isNotEmpty) s.client,
                      if (s.lotCode != null) s.lotCode!,
                      if (s.discount > 0) 'remise ${formatFcfa(s.discount)}',
                    ].join(' · '),
                    amount: s.amount,
                    remaining: s.remaining,
                    remainingLabel: 'reste à recouvrer',
                    chip: paymentChip(s.status),
                    onTap: () => _detail(context, s),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      );

  Future<void> _detail(BuildContext context, Sale s) => _operationSheet(
        context,
        title: s.category.label,
        rows: [
          ('Date', formatDate(s.date)),
          ('Production', s.production?.label ?? 'Toute la ferme'),
          if (s.lotCode != null) ('Lot', s.lotCode!),
          if (s.client.isNotEmpty) ('Client', s.client),
          ('Quantité', '${formatInt(s.quantity)} ${s.category.unit}(s)'),
          ('Prix unitaire', formatFcfa(s.unitPrice)),
          if (s.discount > 0) ('Remise accordée', formatFcfa(s.discount)),
          ('Montant', formatFcfa(s.amount)),
          ('Encaissé', formatFcfa(s.amountPaid)),
          ('Reste à recouvrer', formatFcfa(s.remaining)),
          if (s.description.isNotEmpty) ('Observations', s.description),
        ],
        remaining: s.remaining,
        payLabel: 'Ajouter un encaissement',
        onPay: (v) async {
          s.collect(v);
          await ctx.finance.changed();
        },
        onDelete: () async {
          await ctx.finance.deleteSale(s.id);
          await ctx.lots.removeMovementsFor(s.id); // l'effectif du lot est rétabli
        },
      );
}

class SaleForm extends StatefulWidget {
  const SaleForm({super.key, required this.ctx});
  final FinanceContext ctx;

  @override
  State<SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends State<SaleForm> {
  final _form = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _discount = TextEditingController();
  final _paid = TextEditingController();
  final _client = TextEditingController();
  final _obs = TextEditingController();
  late DateTime _date = widget.ctx.today;
  late final List<SaleCategory> _categories = saleCategoriesFor(widget.ctx.production, widget.ctx.options);
  late SaleCategory _category = _categories.first;
  String? _lotCode;
  bool _fullyPaid = true;

  @override
  void initState() {
    super.initState();
    _applyLastPrice();
    for (final c in [_qty, _price, _discount, _paid]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_qty, _price, _discount, _paid, _client, _obs]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyLastPrice() {
    final p = widget.ctx.finance.lastPrice(_category);
    _price.text = p?.toString() ?? '';
  }

  int get _amount =>
      (int.tryParse(_qty.text) ?? 0) * (int.tryParse(_price.text) ?? 0) - (int.tryParse(_discount.text) ?? 0);

  /// Lots proposés : sujets → lots de sujets en cours ; poussins → lots
  /// d'œufs éclos ; service de couvaison → lots clients.
  List<(String, String)> get _lotChoices {
    final c = widget.ctx;
    switch (_category) {
      case SaleCategory.sujets:
        return [
          for (final l in c.lots.animalLots(c.production).where((l) => l.status == LotStatus.enCours))
            (l.code, '${l.code} · ${l.breed} · ${formatInt(l.current)} sujets'),
        ];
      case SaleCategory.poussins:
        return [
          for (final l in c.lots.incubationLots.where((l) => l.hasResult).take(20))
            (l.code, '${l.code} · ${formatInt(l.alive!)} poussins vivants'),
        ];
      case SaleCategory.serviceCouvaison:
        return [
          for (final l in c.lots.incubationLots.where((l) => l.ownerType == OwnerType.client).take(20))
            (l.code, '${l.code} · ${l.ownerName} · ${formatInt(l.eggsSet)} œufs'),
        ];
      default:
        return const [];
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final c = widget.ctx;
    try {
      final amount = _amount;
      final sale = Sale(
        id: c.finance.newId(),
        date: _date,
        category: _category,
        quantity: int.parse(_qty.text),
        unitPrice: int.parse(_price.text),
        discount: int.tryParse(_discount.text) ?? 0,
        amountPaid: _fullyPaid ? amount : (int.tryParse(_paid.text) ?? 0),
        production: c.production,
        lotCode: _lotCode,
        client: _client.text.trim(),
        description: _obs.text.trim(),
      );
      // Vente de sujets liée à un lot : l'effectif du lot diminue.
      if (_category == SaleCategory.sujets && _lotCode != null) {
        final lot = c.lots.animalLots(c.production).firstWhere((l) => l.code == _lotCode);
        lot.addMovement(Movement(date: _date, type: MovementType.vente, count: sale.quantity,
            note: sale.client.isEmpty ? 'vente' : 'vente à ${sale.client}', ref: sale.id));
        await c.lots.changed();
      }
      await c.finance.addSale(sale);
      if (mounted) {
        Navigator.of(context).pop();
        showInfo(context, 'Vente enregistrée : ${formatFcfa(sale.amount)}.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lots = _lotChoices;
    if (_lotCode != null && !lots.any((l) => l.$1 == _lotCode)) _lotCode = null;
    final clients = widget.ctx.finance.clients;
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Que vendez-vous ?', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final cat in _categories)
                ChoiceChip(
                  key: ValueKey('cat-${cat.name}'),
                  label: Text(cat.label),
                  selected: cat == _category,
                  onSelected: (_) => setState(() {
                    _category = cat;
                    _applyLastPrice();
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            DateField(label: 'Date de la vente', value: _date, last: widget.ctx.today, onChanged: (d) => setState(() => _date = d)),
            if (lots.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _lotCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Lot concerné (conseillé)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucun lot')),
                  for (final l in lots) DropdownMenuItem(value: l.$1, child: Text(l.$2, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _lotCode = v),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _client,
              decoration: const InputDecoration(labelText: 'Client (facultatif)', border: OutlineInputBorder()),
            ),
            if (clients.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                for (final cl in clients.take(8))
                  ActionChip(label: Text(cl), onPressed: () => setState(() => _client.text = cl)),
              ]),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: IntField(key: const ValueKey('quantite'), controller: _qty, label: 'Quantité', suffix: _category.unit, min: 1)),
              const SizedBox(width: 12),
              Expanded(child: IntField(key: const ValueKey('prix'), controller: _price, label: 'Prix unitaire', suffix: 'FCFA')),
            ]),
            const SizedBox(height: 12),
            IntField(controller: _discount, label: 'Remise accordée (facultatif)', suffix: 'FCFA', optional: true),
            const SizedBox(height: 12),
            Card(
              color: NafaColors.greenLight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: InfoRow('Montant de la vente', _amount < 0 ? '—' : formatFcfa(_amount)),
              ),
            ),
            SwitchListTile(
              key: const ValueKey('paye-totalite'),
              contentPadding: EdgeInsets.zero,
              value: _fullyPaid,
              onChanged: (v) => setState(() => _fullyPaid = v),
              title: const Text('Le client a tout payé'),
            ),
            if (!_fullyPaid)
              IntField(key: const ValueKey('encaisse'), controller: _paid, label: 'Montant encaissé', suffix: 'FCFA', optional: true),
            const SizedBox(height: 12),
            TextFormField(
              controller: _obs,
              decoration: const InputDecoration(labelText: 'Observations (facultatif)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton(key: const ValueKey('enregistrer'), onPressed: _save, child: const Text('Enregistrer la vente')),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Dépenses ─────────────────────────────

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key, required this.ctx});
  final FinanceContext ctx;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ctx.finance,
        builder: (context, _) {
          final list = ctx.finance.expenses;
          final t = Totals();
          list.forEach(t.addExpense);
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              key: const ValueKey('nouvelle-depense'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  fullscreenDialog: true, builder: (_) => ExpenseForm(ctx: ctx))),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle dépense'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                const Text('Dépenses', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SectionCard(title: 'Depuis le début', children: [
                  InfoRow('Total des dépenses', formatFcfa(t.expenses)),
                  InfoRow('Payé', formatFcfa(t.paid)),
                  InfoRow('Reste à payer', formatFcfa(t.toPay), valueColor: t.toPay > 0 ? NafaColors.urgent : null),
                ]),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucune dépense',
                    message: 'Enregistrez vos achats : aliment, poussins, vaccins, transport, main-d’œuvre…',
                  ),
                for (final e in list) ...[
                  _OperationTile(
                    key: ValueKey('depense-${e.id}'),
                    title: e.description.isEmpty ? e.category.label : '${e.category.label} · ${e.description}',
                    subtitle: [
                      formatDate(e.date),
                      e.production?.label ?? 'Toute la ferme',
                      if (e.lotCode != null) e.lotCode!,
                      if (e.supplier.isNotEmpty) e.supplier,
                    ].join(' · '),
                    amount: e.amount,
                    remaining: e.remaining,
                    remainingLabel: 'reste à payer',
                    chip: paymentChip(e.status),
                    onTap: () => _detail(context, e),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      );

  Future<void> _detail(BuildContext context, Expense e) => _operationSheet(
        context,
        title: e.category.label,
        rows: [
          ('Date', formatDate(e.date)),
          ('Affectation', e.production?.label ?? 'Toute la ferme (dépense générale)'),
          if (e.lotCode != null) ('Lot', e.lotCode!),
          if (e.supplier.isNotEmpty) ('Fournisseur', e.supplier),
          if (e.description.isNotEmpty) ('Description', e.description),
          ('Quantité', formatInt(e.quantity)),
          ('Prix unitaire', formatFcfa(e.unitPrice)),
          ('Montant', formatFcfa(e.amount)),
          ('Payé', formatFcfa(e.amountPaid)),
          ('Reste à payer', formatFcfa(e.remaining)),
        ],
        remaining: e.remaining,
        payLabel: 'Ajouter un paiement',
        onPay: (v) async {
          e.pay(v);
          await ctx.finance.changed();
        },
        onDelete: () => ctx.finance.deleteExpense(e.id),
      );
}

class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key, required this.ctx});
  final FinanceContext ctx;

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _form = GlobalKey<FormState>();
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _paid = TextEditingController();
  final _desc = TextEditingController();
  final _supplier = TextEditingController();
  late DateTime _date = widget.ctx.today;
  ExpenseCategory _category = ExpenseCategory.aliment;
  bool _generalExpense = false;
  String? _lotCode;
  bool _fullyPaid = true;

  @override
  void initState() {
    super.initState();
    for (final c in [_qty, _price]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_qty, _price, _paid, _desc, _supplier]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _amount => (int.tryParse(_qty.text) ?? 0) * (int.tryParse(_price.text) ?? 0);

  List<(String, String)> get _lots {
    final c = widget.ctx;
    if (c.production == ProductionType.couveuse) {
      return [for (final l in c.lots.incubationLots.take(20)) (l.code, '${l.code} · ${formatInt(l.eggsSet)} œufs')];
    }
    return [
      for (final l in c.lots.animalLots(c.production).where((l) => l.status == LotStatus.enCours))
        (l.code, '${l.code} · ${l.breed}'),
    ];
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final c = widget.ctx;
    try {
      final e = Expense(
        id: c.finance.newId(),
        date: _date,
        category: _category,
        quantity: int.parse(_qty.text),
        unitPrice: int.parse(_price.text),
        amountPaid: _fullyPaid ? _amount : (int.tryParse(_paid.text) ?? 0),
        production: _generalExpense ? null : c.production,
        lotCode: _generalExpense ? null : _lotCode,
        supplier: _supplier.text.trim(),
        description: _desc.text.trim(),
      );
      await c.finance.addExpense(e);
      if (mounted) {
        Navigator.of(context).pop();
        showInfo(context, 'Dépense enregistrée : ${formatFcfa(e.amount)}.');
      }
    } catch (err) {
      if (mounted) showError(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lots = _lots;
    final suppliers = widget.ctx.finance.suppliers;
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle dépense')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Type de dépense', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final cat in ExpenseCategory.values)
                ChoiceChip(
                  key: ValueKey('dep-${cat.name}'),
                  label: Text(cat.label),
                  selected: cat == _category,
                  onSelected: (_) => setState(() => _category = cat),
                ),
            ]),
            const SizedBox(height: 12),
            DateField(label: 'Date', value: _date, last: widget.ctx.today, onChanged: (d) => setState(() => _date = d)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description (ex. aliment démarrage)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _supplier,
              decoration: const InputDecoration(labelText: 'Fournisseur (facultatif)', border: OutlineInputBorder()),
            ),
            if (suppliers.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                for (final s in suppliers.take(8))
                  ActionChip(label: Text(s), onPressed: () => setState(() => _supplier.text = s)),
              ]),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: IntField(key: const ValueKey('quantite'), controller: _qty, label: 'Quantité', min: 1)),
              const SizedBox(width: 12),
              Expanded(child: IntField(key: const ValueKey('prix'), controller: _price, label: 'Prix unitaire', suffix: 'FCFA')),
            ]),
            const SizedBox(height: 12),
            Card(
              color: NafaColors.greenLight,
              child: Padding(padding: const EdgeInsets.all(12), child: InfoRow('Montant', formatFcfa(_amount))),
            ),
            SwitchListTile(
              key: const ValueKey('depense-generale'),
              contentPadding: EdgeInsets.zero,
              value: _generalExpense,
              onChanged: (v) => setState(() => _generalExpense = v),
              title: const Text('Dépense générale de la ferme'),
              subtitle: Text(_generalExpense
                  ? 'Gardée à part, non répartie entre les lots.'
                  : 'Rattachée à : ${widget.ctx.production.label}'),
            ),
            if (!_generalExpense && lots.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: _lotCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Lot concerné (facultatif)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucun lot précis')),
                  for (final l in lots) DropdownMenuItem(value: l.$1, child: Text(l.$2, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _lotCode = v),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _fullyPaid,
              onChanged: (v) => setState(() => _fullyPaid = v),
              title: const Text('Payé en totalité'),
            ),
            if (!_fullyPaid)
              IntField(controller: _paid, label: 'Montant déjà payé', suffix: 'FCFA', optional: true),
            const SizedBox(height: 20),
            FilledButton(key: const ValueKey('enregistrer'), onPressed: _save, child: const Text('Enregistrer la dépense')),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Comptabilité ───────────────────────────

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key, required this.ctx});
  final FinanceContext ctx;

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  DateTime? _month; // null = depuis le début

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.ctx.finance,
        builder: (context, _) {
          final all = widget.ctx.finance.accounting();
          final months = all.monthly.map((m) => m.$1).toList().reversed.toList();
          if (_month != null && !months.contains(_month)) _month = null;
          final acc = widget.ctx.finance.accounting(_month == null ? const Period.all() : Period.month(_month!));
          final g = acc.global;
          final byProd = acc.byProduction;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Comptabilité générale', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Toutes les productions et toute la ferme.', style: TextStyle(color: NafaColors.textMuted)),
              const SizedBox(height: 12),
              DropdownButtonFormField<DateTime?>(
                key: const ValueKey('periode'),
                initialValue: _month,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Période', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Depuis le début')),
                  for (final m in months) DropdownMenuItem(value: m, child: Text(_monthLabel(m))),
                ],
                onChanged: (v) => setState(() => _month = v),
              ),
              const SizedBox(height: 12),
              SectionCard(title: 'Résultat global', children: [
                InfoRow('Chiffre d’affaires', formatFcfa(g.sales)),
                InfoRow('Dépenses', formatFcfa(g.expenses)),
                InfoRow('Bénéfice', formatFcfa(g.profit), valueColor: g.profit < 0 ? NafaColors.urgent : NafaColors.ok),
                InfoRow('Marge', formatPercent(g.margin)),
                const Divider(),
                InfoRow('Encaissé', formatFcfa(g.collected)),
                InfoRow('Reste à recouvrer', formatFcfa(g.toCollect), valueColor: g.toCollect > 0 ? NafaColors.urgent : null),
                InfoRow('Payé', formatFcfa(g.paid)),
                InfoRow('Reste à payer', formatFcfa(g.toPay), valueColor: g.toPay > 0 ? NafaColors.urgent : null),
                InfoRow('Trésorerie (encaissé − payé)', formatFcfa(g.cash)),
                if (g.discounts > 0) InfoRow('Remises accordées', formatFcfa(g.discounts)),
              ]),
              const SizedBox(height: 12),
              SectionCard(title: 'Résultat par production', children: [
                if (byProd.isEmpty)
                  const Text('Aucune opération sur la période.', style: TextStyle(color: NafaColors.textMuted)),
                for (final p in [...ProductionType.values, null])
                  if (byProd[p] != null)
                    InfoRow(
                      p?.label ?? 'Toute la ferme (dépenses générales)',
                      '${formatFcfa(byProd[p]!.profit)}\nventes ${formatFcfa(byProd[p]!.sales)} · dépenses ${formatFcfa(byProd[p]!.expenses)}',
                      valueColor: byProd[p]!.profit < 0 ? NafaColors.urgent : null,
                    ),
              ]),
              const SizedBox(height: 12),
              SectionCard(title: 'Ventes par catégorie', children: [
                for (final e in acc.salesByCategory.entries) InfoRow(e.key.label, formatFcfa(e.value)),
                if (acc.salesByCategory.isEmpty) const Text('—'),
              ]),
              const SizedBox(height: 12),
              SectionCard(title: 'Dépenses par catégorie', children: [
                for (final e in acc.expensesByCategory.entries) InfoRow(e.key.label, formatFcfa(e.value)),
                if (acc.expensesByCategory.isEmpty) const Text('—'),
              ]),
              if (acc.byLot.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionCard(title: 'Marge par lot (ventes − dépenses directes)', children: [
                  for (final e in acc.byLot.entries)
                    InfoRow(e.key, formatFcfa(e.value.profit), valueColor: e.value.profit < 0 ? NafaColors.urgent : null),
                ]),
              ],
              const SizedBox(height: 12),
              SectionCard(title: 'Évolution mensuelle', children: [
                if (all.monthly.isEmpty) const Text('—'),
                for (final (m, t) in all.monthly.reversed)
                  InfoRow(_monthLabel(m),
                      'résultat ${formatFcfa(t.profit)}\nventes ${formatFcfa(t.sales)} · dépenses ${formatFcfa(t.expenses)}',
                      valueColor: t.profit < 0 ? NafaColors.urgent : null),
              ]),
            ],
          );
        },
      );
}

const _monthNames = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
];
String _monthLabel(DateTime m) => '${_monthNames[m.month - 1]} ${m.year}';

// ───────────────────────────── Communs ─────────────────────────────

class _OperationTile extends StatelessWidget {
  const _OperationTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.remaining,
    required this.remainingLabel,
    required this.chip,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final int amount;
  final int remaining;
  final String remainingLabel;
  final Widget chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(formatFcfa(amount),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: NafaColors.textMuted)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                chip,
                if (remaining > 0)
                  Text('$remainingLabel : ${formatFcfa(remaining)}',
                      style: const TextStyle(color: NafaColors.urgent, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ),
      );
}

Future<void> _operationSheet(
  BuildContext context, {
  required String title,
  required List<(String, String)> rows,
  required int remaining,
  required String payLabel,
  required Future<void> Function(int) onPay,
  required Future<void> Function() onDelete,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final r in rows) InfoRow(r.$1, r.$2),
            const SizedBox(height: 12),
            if (remaining > 0)
              FilledButton(
                key: const ValueKey('ajouter-paiement'),
                onPressed: () async {
                  final ctrl = TextEditingController(text: '$remaining');
                  final form = GlobalKey<FormState>();
                  final ok = await showDialog<bool>(
                    context: sheet,
                    builder: (d) => AlertDialog(
                      title: Text(payLabel),
                      content: Form(
                        key: form,
                        child: IntField(controller: ctrl, label: 'Montant', suffix: 'FCFA', min: 1, max: remaining),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
                        FilledButton(
                            onPressed: () {
                              if (form.currentState!.validate()) Navigator.pop(d, true);
                            },
                            child: const Text('Valider')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await onPay(int.parse(ctrl.text));
                    if (sheet.mounted) Navigator.pop(sheet);
                  }
                },
                child: Text(payLabel),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: NafaColors.urgent),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: sheet,
                  builder: (d) => AlertDialog(
                    title: const Text('Supprimer cette opération ?'),
                    content: const Text('Elle sera retirée de la comptabilité.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
                      FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Supprimer')),
                    ],
                  ),
                );
                if (ok == true) {
                  await onDelete();
                  if (sheet.mounted) Navigator.pop(sheet);
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
            ),
          ]),
        ),
      ),
    );
