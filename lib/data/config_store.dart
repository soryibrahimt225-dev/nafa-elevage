import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/config.dart';
import '../domain/finance.dart';
import '../domain/incubation.dart';
import '../domain/production.dart';
import '../domain/reminders.dart';

/// Paramètres modifiables (espèces, races, prix, cycles), enregistrés
/// sur l'appareil.
class ConfigStore extends ChangeNotifier {
  ConfigStore(this._prefs) {
    final raw = _prefs.getString(_key);
    config = raw == null ? FarmConfig() : FarmConfig.fromJson((jsonDecode(raw) as Map).cast());
  }

  static const _key = 'nafa.config.v1';
  final SharedPreferences _prefs;
  late FarmConfig config;

  static Future<ConfigStore> load() async => ConfigStore(await SharedPreferences.getInstance());

  List<SpeciesProfile> get species => List.unmodifiable(config.species);
  List<String> breedsFor(ProductionType p) => List.unmodifiable(config.breeds[p] ?? const []);
  int? priceFor(SaleCategory c) => config.prices[c];
  ImprovedCycle cycleFor(String breed) => config.cycleFor(breed);

  Future<void> setSpecies(SpeciesProfile p) async {
    config.setSpecies(p);
    await _save();
  }

  Future<void> addBreed(ProductionType p, String breed) async {
    config.addBreed(p, breed);
    await _save();
  }

  Future<void> removeBreed(ProductionType p, String breed) async {
    config.breeds[p]?.remove(breed);
    await _save();
  }

  Future<void> setPrice(SaleCategory c, int? price) async {
    if (price != null && price < 0) throw ArgumentError('Le prix ne peut pas être négatif.');
    price == null ? config.prices.remove(c) : config.prices[c] = price;
    await _save();
  }

  Future<void> setCycle(String breed, ImprovedCycle cycle) async {
    ImprovedCycle.validate(cycle.selectionMonths, cycle.layingStartMonths, cycle.productionReviewMonths,
        cycle.reformReviewMonths);
    config.cycles[breed] = cycle;
    await _save();
  }

  ReminderPrefs get reminders => config.reminders;

  Future<void> setReminders(ReminderPrefs prefs) async {
    if (prefs.hour < 0 || prefs.hour > 23) throw ArgumentError('Heure invalide.');
    config.reminders = prefs;
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode(config.toJson()));
    notifyListeners();
  }
}
