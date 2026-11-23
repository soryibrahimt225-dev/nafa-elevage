import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/finance_store.dart';
import 'package:nafa_elevage/domain/finance.dart';
import 'package:nafa_elevage/domain/production.dart';
import 'package:shared_preferences/shared_preferences.dart';

var _n = 0;
Sale sale(int q, int p, int paid, {DateTime? d, int discount = 0, ProductionType? prod = ProductionType.couveuse,
        SaleCategory c = SaleCategory.poussins, String? lot}) =>
    Sale(id: 's${_n++}', date: d ?? DateTime(2026, 9, 3), category: c, quantity: q, unitPrice: p,
        amountPaid: paid, discount: discount, production: prod, lotCode: lot);

Expense exp(int amount, int paid, {DateTime? d, ProductionType? prod = ProductionType.couveuse,
        ExpenseCategory c = ExpenseCategory.aliment, String? lot}) =>
    Expense(id: 'e${_n++}', date: d ?? DateTime(2026, 11, 11), category: c, quantity: 1, unitPrice: amount,
        amountPaid: paid, production: prod, lotCode: lot);

void main() {
  group('Ventes (exemples du classeur)', () {
    test('CARA : 25 poussins à 600 FCFA, 12 000 encaissés → partiel, reste 3 000', () {
      final s = sale(25, 600, 12000);
      expect(s.amount, 15000);
      expect(s.remaining, 3000);
      expect(s.status, PaymentStatus.partiel);
    });
    test('remise explicite : 56 × 200 = 11 200, remise 200, encaissé 11 000 → payé', () {
      final s = sale(56, 200, 11000, discount: 200, c: SaleCategory.serviceCouvaison);
      expect(s.amount, 11000);
      expect(s.status, PaymentStatus.paye);
    });
    test('encaissement supérieur au montant refusé (le −20 FCFA du classeur)', () {
      expect(() => sale(11, 680, 7500), throwsArgumentError);
    });
    test('impayé puis encaissements successifs', () {
      final s = sale(2, 7000, 0, c: SaleCategory.alveoles);
      expect(s.status, PaymentStatus.impaye);
      s.collect(1400);
      expect(s.remaining, 12600);
      expect(() => s.collect(12601), throwsArgumentError);
      s.collect(12600);
      expect(s.status, PaymentStatus.paye);
    });
    test('saisies invalides', () {
      expect(() => sale(0, 700, 0), throwsArgumentError);
      expect(() => sale(1, -5, 0), throwsArgumentError);
      expect(() => sale(1, 700, 0, discount: 800), throwsArgumentError);
    });
  });

  group('Comptabilité générale', () {
    final sales = [
      sale(25, 600, 12000, d: DateTime(2026, 8, 17)),
      sale(128, 700, 89600, d: DateTime(2026, 11, 11)),
      sale(50, 3500, 175000, d: DateTime(2026, 11, 15), prod: ProductionType.chair, c: SaleCategory.sujets, lot: 'CHA-26-001'),
    ];
    final expenses = [
      exp(28500, 28500),
      exp(24000, 20000),
      exp(10000, 10000, d: DateTime(2026, 10, 28), prod: null, c: ExpenseCategory.mainOeuvre),
      exp(42000, 42000, prod: ProductionType.chair, c: ExpenseCategory.poussins, lot: 'CHA-26-001'),
    ];
    final acc = Accounting(sales, expenses);

    test('totaux globaux', () {
      final g = acc.global;
      expect(g.sales, 15000 + 89600 + 175000);
      expect(g.collected, 12000 + 89600 + 175000);
      expect(g.toCollect, 3000);
      expect(g.expenses, 104500);
      expect(g.toPay, 4000);
      expect(g.profit, 279600 - 104500);
      expect(g.cash, 276600 - 100500);
    });
    test('par production, dépenses générales à part', () {
      final m = acc.byProduction;
      expect(m[ProductionType.couveuse]!.profit, 104600 - 52500);
      expect(m[ProductionType.chair]!.profit, 175000 - 42000);
      expect(m[null]!.expenses, 10000);
      expect(m[null]!.sales, 0);
      final sum = m.values.fold(0, (s, t) => s + t.profit);
      expect(sum, acc.global.profit, reason: 'rien ne se perd entre les productions');
    });
    test('marge par lot', () => expect(acc.byLot['CHA-26-001']!.profit, 133000));
    test('période : novembre 2026', () {
      final nov = Accounting(sales, expenses, period: Period.month(DateTime(2026, 11, 22))).global;
      expect(nov.sales, 89600 + 175000);
      expect(nov.expenses, 28500 + 24000 + 42000);
    });
    test('évolution mensuelle avec mois vides', () {
      final m = acc.monthly;
      expect(m.map((e) => e.$1.month), [8, 9, 10, 11]);
      expect(m[1].$2.sales, 0); // septembre : aucune opération
      expect(m.fold(0, (s, e) => s + e.$2.profit), acc.global.profit);
    });
    test('marge vide sans ventes', () => expect(Accounting([], []).global.margin, isNull));
  });

  test('Catégories de vente selon la production', () {
    expect(saleCategoriesFor(ProductionType.chair, {}), isNot(contains(SaleCategory.poussins)));
    expect(saleCategoriesFor(ProductionType.couveuse, {}), contains(SaleCategory.serviceCouvaison));
    expect(saleCategoriesFor(ProductionType.ameliorees, {}), isNot(contains(SaleCategory.oeufsFertiles)));
    expect(saleCategoriesFor(ProductionType.ameliorees, {OptionalFeature.couvaisonConversion}),
        contains(SaleCategory.oeufsFertiles));
  });

  test('Enregistrement des ventes et dépenses', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await FinanceStore.load();
    await store.addSale(sale(10, 700, 7000));
    await store.addExpense(exp(1000, 0));
    final again = await FinanceStore.load();
    expect(again.sales.single.amount, 7000);
    expect(again.expenses.single.status, PaymentStatus.impaye);
    expect(again.lastPrice(SaleCategory.poussins), 700);
  });

  test('Œufs vendus à l’alvéole', () {
    final s = sale(4, 2500, 10000, c: SaleCategory.oeufsTable, prod: ProductionType.pondeuses);
    expect(SaleCategory.oeufsTable.unit, 'alvéole');
    expect(eggsInSale(s, 30), 120);
    expect(eggsInSale(sale(10, 200, 2000, c: SaleCategory.oeufsFertiles), 30), 10);
    expect(eggsInSale(sale(1, 700, 700), 30), 0);
  });

  test('Types vendus : un prix par type de sujet', () async {
    expect(defaultVariants(ProductionType.ameliorees, SaleCategory.sujets),
        ['Sujet de 2 mois (engraissement)', 'Sujet de 6 mois', 'Sujet de réforme']);
    final v = Sale(id: 'v', date: DateTime(2026, 11, 23), category: SaleCategory.sujets, quantity: 5, unitPrice: 4500,
        amountPaid: 22500, variant: 'Sujet de réforme');
    expect(v.label, 'Sujets · Sujet de réforme');
    expect(Sale.fromJson(v.toJson()).variant, 'Sujet de réforme');
  });
}
