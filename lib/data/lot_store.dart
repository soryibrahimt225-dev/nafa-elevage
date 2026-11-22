import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/lots.dart';
import '../domain/production.dart';

/// Lots enregistrés sur l'appareil (hors connexion).
/// Stockage JSON local pour ce lot de développement ; la base de données et la
/// synchronisation sont prévues au lot « sauvegarde et synchronisation ».
class LotStore extends ChangeNotifier {
  LotStore(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      _animal.addAll([
        for (final e in (j['animal'] as List? ?? const []))
          AnimalLot.fromJson((e as Map).cast<String, Object?>())
      ]);
      _incubation.addAll([
        for (final e in (j['incubation'] as List? ?? const []))
          IncubationLot.fromJson((e as Map).cast<String, Object?>())
      ]);
    }
  }

  static const _key = 'nafa.lots.v1';
  final SharedPreferences _prefs;
  final List<AnimalLot> _animal = [];
  final List<IncubationLot> _incubation = [];
  final _rand = Random();

  static Future<LotStore> load() async => LotStore(await SharedPreferences.getInstance());

  /// Lots de sujets d'une production, les plus récents d'abord.
  /// Une production ne voit jamais les lots d'une autre (pas de mélange).
  List<AnimalLot> animalLots(ProductionType p) =>
      _animal.where((l) => l.production == p).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

  List<IncubationLot> get incubationLots =>
      [..._incubation]..sort((a, b) => b.entryDate.compareTo(a.entryDate));

  Iterable<String> get _allCodes => [..._animal.map((l) => l.code), ..._incubation.map((l) => l.code)];

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(1 << 32)}';

  String nextAnimalCode(ProductionType p, DateTime date) => nextLotCode(animalPrefix(p), date, _allCodes);
  String nextIncubationCode(OwnerType o, DateTime date) => nextLotCode(o.prefix, date, _allCodes);

  Iterable<String> get codes => _allCodes;

  Future<void> addAnimalLot(AnimalLot lot) async {
    _ensureUnique(lot.code);
    _animal.add(lot);
    await _save();
  }

  Future<void> addIncubationLot(IncubationLot lot) async {
    _ensureUnique(lot.code);
    _incubation.add(lot);
    await _save();
  }

  Future<void> addIncubationLots(Iterable<IncubationLot> lots) async {
    for (final l in lots) {
      _ensureUnique(l.code);
    }
    _incubation.addAll(lots);
    await _save();
  }

  /// À appeler après une modification d'un lot (sortie, éclosion, notes…).
  Future<void> changed() => _save();

  /// Annule les sorties liées à une opération supprimée.
  Future<void> removeMovementsFor(String ref) async {
    var changed = false;
    for (final l in _animal) {
      changed = l.removeMovementsFor(ref) || changed;
    }
    if (changed) await _save();
  }

  Future<void> deleteAnimalLot(String id) async {
    _animal.removeWhere((l) => l.id == id);
    await _save();
  }

  Future<void> deleteIncubationLot(String id) async {
    _incubation.removeWhere((l) => l.id == id);
    await _save();
  }

  void _ensureUnique(String code) {
    if (_allCodes.contains(code)) throw ArgumentError('Le code $code existe déjà.');
  }

  Future<void> _save() async {
    await _prefs.setString(
        _key,
        jsonEncode({
          'animal': [for (final l in _animal) l.toJson()],
          'incubation': [for (final l in _incubation) l.toJson()],
        }));
    notifyListeners();
  }
}
