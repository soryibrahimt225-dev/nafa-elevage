import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/finance.dart';

/// Ventes et dépenses enregistrées sur l'appareil.
class FinanceStore extends ChangeNotifier {
  FinanceStore(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      _sales.addAll([
        for (final e in (j['sales'] as List? ?? const [])) Sale.fromJson((e as Map).cast<String, Object?>())
      ]);
      _expenses.addAll([
        for (final e in (j['expenses'] as List? ?? const [])) Expense.fromJson((e as Map).cast<String, Object?>())
      ]);
    }
  }

  static const _key = 'nafa.finance.v1';
  final SharedPreferences _prefs;
  final List<Sale> _sales = [];
  final List<Expense> _expenses = [];
  final _rand = Random();

  static Future<FinanceStore> load() async => FinanceStore(await SharedPreferences.getInstance());

  /// Les plus récentes d'abord.
  List<Sale> get sales => [..._sales]..sort((a, b) => b.date.compareTo(a.date));
  List<Expense> get expenses => [..._expenses]..sort((a, b) => b.date.compareTo(a.date));

  Accounting accounting([Period period = const Period.all()]) => Accounting(_sales, _expenses, period: period);

  /// Clients déjà saisis (pour la saisie rapide).
  List<String> get clients => {for (final s in _sales) if (s.client.isNotEmpty) s.client}.toList()..sort();
  List<String> get suppliers => {for (final e in _expenses) if (e.supplier.isNotEmpty) e.supplier}.toList()..sort();

  /// Poussins vendus rattachés à un lot d'œufs.
  int chicksSoldFrom(String lotCode) => _sales
      .where((s) => s.category == SaleCategory.poussins && s.lotCode == lotCode)
      .fold(0, (n, s) => n + s.quantity);

  /// Dernier prix pratiqué pour une catégorie (proposé par défaut).
  int? lastPrice(SaleCategory c) {
    for (final s in sales) {
      if (s.category == c) return s.unitPrice;
    }
    return null;
  }

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(1 << 32)}';

  Future<void> addSale(Sale s) async {
    _sales.add(s);
    await _save();
  }

  Future<void> addExpense(Expense e) async {
    _expenses.add(e);
    await _save();
  }

  Future<void> deleteSale(String id) async {
    _sales.removeWhere((s) => s.id == id);
    await _save();
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> changed() => _save();

  Future<void> _save() async {
    await _prefs.setString(
        _key,
        jsonEncode({
          'sales': [for (final s in _sales) s.toJson()],
          'expenses': [for (final e in _expenses) e.toJson()],
        }));
    notifyListeners();
  }
}
