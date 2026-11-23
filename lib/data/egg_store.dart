import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/eggs.dart';

/// Ramassages d'œufs, un par lot et par jour.
class EggStore extends ChangeNotifier {
  EggStore(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      _records.addAll([for (final e in jsonDecode(raw) as List) EggRecord.fromJson((e as Map).cast())]);
    }
  }

  static const _key = 'nafa.eggs.v1';
  final SharedPreferences _prefs;
  final List<EggRecord> _records = [];

  static Future<EggStore> load() async => EggStore(await SharedPreferences.getInstance());

  /// Les plus récents d'abord.
  List<EggRecord> forLots(Set<String> codes) =>
      _records.where((r) => codes.contains(r.lotCode)).toList()..sort((a, b) => b.date.compareTo(a.date));

  List<EggRecord> between(Set<String> codes, DateTime from, DateTime to) => forLots(codes)
      .where((r) => !r.date.isBefore(DateTime(from.year, from.month, from.day)) &&
          !r.date.isAfter(DateTime(to.year, to.month, to.day)))
      .toList();

  EggRecord? find(String lotCode, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    for (final r in _records) {
      if (r.lotCode == lotCode && r.date == d) return r;
    }
    return null;
  }

  /// Enregistre le ramassage du jour (remplace la saisie existante du même
  /// lot et du même jour : pas de double comptage).
  Future<void> save(EggRecord r) async {
    _records.removeWhere((x) => x.lotCode == r.lotCode && x.date == r.date);
    _records.add(r);
    await _persist();
  }

  Future<void> delete(EggRecord r) async {
    _records.remove(r);
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode([for (final r in _records) r.toJson()]));
    notifyListeners();
  }
}
