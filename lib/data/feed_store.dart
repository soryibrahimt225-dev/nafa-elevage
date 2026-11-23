import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/feed.dart';

/// Catalogue des aliments et mouvements de stock.
class FeedStore extends ChangeNotifier {
  FeedStore(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      _items.addAll([for (final e in j['items'] as List) FeedItem.fromJson((e as Map).cast())]);
      _moves.addAll([for (final e in j['moves'] as List) FeedMove.fromJson((e as Map).cast())]);
    }
  }

  static const _key = 'nafa.feed.v1';
  final SharedPreferences _prefs;
  final List<FeedItem> _items = [];
  final List<FeedMove> _moves = [];
  final _rand = Random();

  static Future<FeedStore> load() async => FeedStore(await SharedPreferences.getInstance());

  List<FeedItem> get items => List.unmodifiable(_items);

  /// Les plus récents d'abord.
  List<FeedMove> get moves => [..._moves]..sort((a, b) => b.date.compareTo(a.date));

  Map<String, FeedStock> get stocks => {for (final i in _items) i.id: FeedStock(i, _moves)};

  FeedStock stockOf(String itemId) => FeedStock(_items.firstWhere((i) => i.id == itemId), _moves);

  LotFeed forLot(String lotCode) => LotFeed(lotCode, _moves, stocks);

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(1 << 32)}';

  Future<void> saveItem(FeedItem item) async {
    final dup = _items.any((i) => i.id != item.id && i.name.toLowerCase() == item.name.trim().toLowerCase());
    if (dup) throw ArgumentError('Cet aliment existe déjà.');
    final i = _items.indexWhere((x) => x.id == item.id);
    i >= 0 ? _items[i] = item : _items.add(item);
    await _save();
  }

  /// Ajoute un mouvement. Une distribution ou une perte ne peut pas dépasser
  /// le stock restant.
  Future<void> addMove(FeedMove m) async {
    if (m.type != FeedMoveType.achat) {
      final left = stockOf(m.itemId).remainingGrams;
      if (m.grams > left) {
        throw ArgumentError('Stock insuffisant : il reste ${formatKg(left)}.');
      }
    }
    _moves.add(m);
    await _save();
  }

  /// Supprime un mouvement (renvoie la dépense liée, à supprimer aussi).
  /// Un achat déjà en partie distribué ne peut pas être retiré.
  Future<String?> deleteMove(String id) async {
    final m = _moves.firstWhere((x) => x.id == id);
    if (m.type == FeedMoveType.achat && stockOf(m.itemId).remainingGrams < m.grams) {
      throw ArgumentError('Cet achat a déjà été distribué : supprimez d’abord les distributions.');
    }
    _moves.remove(m);
    await _save();
    return m.expenseId;
  }

  Future<void> _save() async {
    await _prefs.setString(
        _key,
        jsonEncode({
          'items': [for (final i in _items) i.toJson()],
          'moves': [for (final m in _moves) m.toJson()],
        }));
    notifyListeners();
  }
}
