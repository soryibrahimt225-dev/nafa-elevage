import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/health.dart';

class HealthStore extends ChangeNotifier {
  HealthStore(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      _records.addAll([
        for (final e in jsonDecode(raw) as List) HealthRecord.fromJson((e as Map).cast<String, Object?>())
      ]);
    }
  }

  static const _key = 'nafa.health.v1';
  final SharedPreferences _prefs;
  final List<HealthRecord> _records = [];
  final _rand = Random();

  static Future<HealthStore> load() async => HealthStore(await SharedPreferences.getInstance());

  /// Soins des lots donnés, du plus urgent au plus ancien réalisé.
  List<HealthRecord> forLots(Set<String> lotCodes, DateTime today) {
    final list = _records.where((r) => lotCodes.contains(r.lotCode)).toList();
    int rank(HealthRecord r) => switch (r.statusAt(today)) {
          HealthStatus.enRetard => 0,
          HealthStatus.aujourdhui => 1,
          HealthStatus.aVenir => 2,
          HealthStatus.realise => 3,
        };
    list.sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      if (c != 0) return c;
      return rank(a) == 3 ? b.doneDate!.compareTo(a.doneDate!) : a.plannedDate.compareTo(b.plannedDate);
    });
    return list;
  }

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(1 << 32)}';

  Future<void> add(HealthRecord r) async {
    _records.add(r);
    await _save();
  }

  Future<void> delete(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _save();
  }

  Future<void> changed() => _save();

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode([for (final r in _records) r.toJson()]));
    notifyListeners();
  }
}
