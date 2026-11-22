import 'production.dart';

/// Catégories de vente. Le service de couvaison et la vente d'œufs fertiles
/// sont séparés (audit, point 13).
enum SaleCategory {
  poussins('Poussins', 'poussin'),
  sujets('Sujets (poulets, poulettes, réformes)', 'sujet'),
  oeufsTable('Œufs de table', 'œuf'),
  oeufsFertiles('Œufs fertiles', 'œuf'),
  serviceCouvaison('Service de couvaison', 'œuf'),
  alveoles('Alvéoles', 'alvéole'),
  autre('Autre', 'unité');

  const SaleCategory(this.label, this.unit);
  final String label;
  final String unit;
}

/// Catégories de dépense (liste fermée, audit point 12).
enum ExpenseCategory {
  aliment('Aliment'),
  poussins('Achat de poussins ou sujets'),
  oeufsACouver('Œufs à couver'),
  veterinaire('Produits vétérinaires'),
  energie('Énergie'),
  materiel('Matériel et équipement'),
  transport('Transport'),
  mainOeuvre('Main-d’œuvre'),
  loyer('Loyer'),
  autre('Autre');

  const ExpenseCategory(this.label);
  final String label;
}

enum PaymentStatus {
  paye('Payé'),
  partiel('Partiel'),
  impaye('Impayé');

  const PaymentStatus(this.label);
  final String label;
}

PaymentStatus _status(int amount, int paid) =>
    paid >= amount ? PaymentStatus.paye : (paid == 0 ? PaymentStatus.impaye : PaymentStatus.partiel);

void _checkAmounts(int quantity, int unitPrice, int discount, int paid) {
  if (quantity <= 0) throw ArgumentError('La quantité doit être supérieure à 0.');
  if (unitPrice < 0) throw ArgumentError('Le prix ne peut pas être négatif.');
  final gross = quantity * unitPrice;
  if (discount < 0 || discount > gross) throw ArgumentError('La remise doit être comprise entre 0 et le montant.');
  if (paid < 0) throw ArgumentError('Le montant payé ne peut pas être négatif.');
  if (paid > gross - discount) {
    throw ArgumentError('Le montant payé dépasse le montant dû.');
  }
}

/// Vente. Montant = quantité × prix unitaire − remise.
/// Reste à recouvrer = montant − encaissé (jamais négatif, audit point 4).
class Sale {
  Sale({
    required this.id,
    required this.date,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    this.production,
    this.lotCode,
    this.client = '',
    this.description = '',
    this.discount = 0,
    required this.amountPaid,
  }) {
    _checkAmounts(quantity, unitPrice, discount, amountPaid);
  }

  final String id;
  final DateTime date;
  final SaleCategory category;
  final int quantity;
  final int unitPrice;

  /// Production concernée ; `null` = toute la ferme.
  final ProductionType? production;
  final String? lotCode;
  final String client;
  final String description;
  final int discount;
  int amountPaid;

  int get amount => quantity * unitPrice - discount;
  int get remaining => amount - amountPaid;
  PaymentStatus get status => _status(amount, amountPaid);

  /// Ajoute un encaissement.
  void collect(int value) {
    if (value <= 0) throw ArgumentError('Le montant doit être supérieur à 0.');
    if (value > remaining) throw ArgumentError('Le montant dépasse le reste à recouvrer.');
    amountPaid += value;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'date': _d(date),
        'category': category.name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'production': production?.name,
        'lotCode': lotCode,
        'client': client,
        'description': description,
        'discount': discount,
        'amountPaid': amountPaid,
      };

  factory Sale.fromJson(Map<String, Object?> j) => Sale(
        id: j['id']! as String,
        date: DateTime.parse(j['date']! as String),
        category: SaleCategory.values.byName(j['category']! as String),
        quantity: j['quantity']! as int,
        unitPrice: j['unitPrice']! as int,
        production: ProductionType.fromName(j['production'] as String?),
        lotCode: j['lotCode'] as String?,
        client: (j['client'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        discount: (j['discount'] as int?) ?? 0,
        amountPaid: j['amountPaid']! as int,
      );
}

/// Dépense. Sans production, c'est une dépense générale de la ferme : elle
/// reste visible séparément et n'est jamais répartie entre les lots sans
/// règle choisie par le producteur.
class Expense {
  Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    this.production,
    this.lotCode,
    this.supplier = '',
    this.description = '',
    required this.amountPaid,
  }) {
    _checkAmounts(quantity, unitPrice, 0, amountPaid);
  }

  final String id;
  final DateTime date;
  final ExpenseCategory category;
  final int quantity;
  final int unitPrice;
  final ProductionType? production;
  final String? lotCode;
  final String supplier;
  final String description;
  int amountPaid;

  int get amount => quantity * unitPrice;
  int get remaining => amount - amountPaid;
  PaymentStatus get status => _status(amount, amountPaid);

  void pay(int value) {
    if (value <= 0) throw ArgumentError('Le montant doit être supérieur à 0.');
    if (value > remaining) throw ArgumentError('Le montant dépasse le reste à payer.');
    amountPaid += value;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'date': _d(date),
        'category': category.name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'production': production?.name,
        'lotCode': lotCode,
        'supplier': supplier,
        'description': description,
        'amountPaid': amountPaid,
      };

  factory Expense.fromJson(Map<String, Object?> j) => Expense(
        id: j['id']! as String,
        date: DateTime.parse(j['date']! as String),
        category: ExpenseCategory.values.byName(j['category']! as String),
        quantity: j['quantity']! as int,
        unitPrice: j['unitPrice']! as int,
        production: ProductionType.fromName(j['production'] as String?),
        lotCode: j['lotCode'] as String?,
        supplier: (j['supplier'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        amountPaid: j['amountPaid']! as int,
      );
}

/// Période d'analyse : un mois précis, ou tout depuis le début.
class Period {
  const Period.all() : month = null;
  Period.month(DateTime d) : month = DateTime(d.year, d.month);
  final DateTime? month;

  bool contains(DateTime d) => month == null || (d.year == month!.year && d.month == month!.month);
}

/// Totaux comptables d'un ensemble d'opérations.
class Totals {
  int sales = 0, collected = 0, expenses = 0, paid = 0, discounts = 0;

  int get toCollect => sales - collected;
  int get toPay => expenses - paid;
  int get profit => sales - expenses;
  double? get margin => sales == 0 ? null : profit / sales;

  /// Trésorerie = encaissements − paiements.
  int get cash => collected - paid;

  void addSale(Sale s) {
    sales += s.amount;
    collected += s.amountPaid;
    discounts += s.discount;
  }

  void addExpense(Expense e) {
    expenses += e.amount;
    paid += e.amountPaid;
  }
}

/// Comptabilité générale : commune à toutes les productions.
class Accounting {
  Accounting(this.sales, this.expenses, {this.period = const Period.all()});
  final List<Sale> sales;
  final List<Expense> expenses;
  final Period period;

  Iterable<Sale> get _s => sales.where((x) => period.contains(x.date));
  Iterable<Expense> get _e => expenses.where((x) => period.contains(x.date));

  Totals get global {
    final t = Totals();
    _s.forEach(t.addSale);
    _e.forEach(t.addExpense);
    return t;
  }

  /// Résultat par production. La clé `null` regroupe les opérations de toute
  /// la ferme (dépenses générales).
  Map<ProductionType?, Totals> get byProduction {
    final m = <ProductionType?, Totals>{};
    for (final s in _s) {
      m.putIfAbsent(s.production, Totals.new).addSale(s);
    }
    for (final e in _e) {
      m.putIfAbsent(e.production, Totals.new).addExpense(e);
    }
    return m;
  }

  /// Résultat par lot (ventes et dépenses directes rattachées au lot).
  Map<String, Totals> get byLot {
    final m = <String, Totals>{};
    for (final s in _s.where((s) => s.lotCode != null)) {
      m.putIfAbsent(s.lotCode!, Totals.new).addSale(s);
    }
    for (final e in _e.where((e) => e.lotCode != null)) {
      m.putIfAbsent(e.lotCode!, Totals.new).addExpense(e);
    }
    return m;
  }

  Map<SaleCategory, int> get salesByCategory {
    final m = <SaleCategory, int>{};
    for (final s in _s) {
      m[s.category] = (m[s.category] ?? 0) + s.amount;
    }
    return m;
  }

  Map<ExpenseCategory, int> get expensesByCategory {
    final m = <ExpenseCategory, int>{};
    for (final e in _e) {
      m[e.category] = (m[e.category] ?? 0) + e.amount;
    }
    return m;
  }

  /// Évolution mensuelle (tous les mois entre la première et la dernière
  /// opération, mois vides compris), sans tenir compte de la période.
  List<(DateTime, Totals)> get monthly {
    final dates = [...sales.map((s) => s.date), ...expenses.map((e) => e.date)];
    if (dates.isEmpty) return const [];
    dates.sort();
    final out = <(DateTime, Totals)>[];
    var m = DateTime(dates.first.year, dates.first.month);
    final last = DateTime(dates.last.year, dates.last.month);
    while (!m.isAfter(last)) {
      final p = Period.month(m);
      final t = Totals();
      sales.where((s) => p.contains(s.date)).forEach(t.addSale);
      expenses.where((e) => p.contains(e.date)).forEach(t.addExpense);
      out.add((m, t));
      m = DateTime(m.year, m.month + 1);
    }
    return out;
  }
}

String _d(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Catégories de vente proposées selon la production et ses options.
List<SaleCategory> saleCategoriesFor(ProductionType p, Set<OptionalFeature> options) {
  final couvaison = options.contains(OptionalFeature.couvaisonConversion) ||
      options.contains(OptionalFeature.couveusePondeuses);
  switch (p) {
    case ProductionType.chair:
      return const [SaleCategory.sujets, SaleCategory.autre];
    case ProductionType.ameliorees:
      return [
        SaleCategory.sujets,
        SaleCategory.oeufsTable,
        if (couvaison) ...[SaleCategory.oeufsFertiles, SaleCategory.poussins],
        SaleCategory.autre,
      ];
    case ProductionType.pondeuses:
      return [
        SaleCategory.oeufsTable,
        SaleCategory.alveoles,
        SaleCategory.sujets,
        if (couvaison) ...[SaleCategory.oeufsFertiles, SaleCategory.poussins],
        SaleCategory.autre,
      ];
    case ProductionType.couveuse:
      return const [
        SaleCategory.poussins,
        SaleCategory.serviceCouvaison,
        SaleCategory.oeufsFertiles,
        SaleCategory.alveoles,
        SaleCategory.autre,
      ];
  }
}
