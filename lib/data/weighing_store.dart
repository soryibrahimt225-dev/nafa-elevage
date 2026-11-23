import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/weighing.dart';

class WeighingStore extends ChangeNotifier {
  WeighingStore(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      _list.addAll([for (final e in jsonDecode(raw) as List) Weighing.fromJson((e as Map).cast())]);
    }
  }

  static const _key = 'nafa.weighings.v1';
  final SharedPreferences _prefs;
  final List<Weighing> _list = [];
  final _rand = Random();

  static Future<WeighingStore> load() async => WeighingStore(await SharedPreferences.getInstance());

  List<Weighing> get all => List.unmodifiable(_list);

  /// Pesées d'un lot, de la plus ancienne à la plus récente.
  List<Weighing> forLot(String code) =>
      _list.where((w) => w.lotCode == code).toList()..sort((a, b) => a.date.compareTo(b.date));

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(1 << 32)}';

  /// Une pesée par lot et par jour : une nouvelle saisie remplace la précédente.
  Future<void> save(Weighing w) async {
    _list.removeWhere((x) => x.lotCode == w.lotCode && x.date == w.date);
    _list.add(w);
    await _persist();
  }

  Future<void> delete(String id) async {
    _list.removeWhere((w) => w.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode([for (final w in _list) w.toJson()]));
    notifyListeners();
  }
}
