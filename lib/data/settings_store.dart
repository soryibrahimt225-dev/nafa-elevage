import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/farm.dart';
import '../domain/production.dart';

/// Configuration de l'exploitation : production choisie et options activées.
/// Stockée localement (hors connexion). La synchronisation viendra au lot 12.
class FarmSettings extends ChangeNotifier {
  FarmSettings(this._prefs) {
    _production = ProductionType.fromName(_prefs.getString(_kProduction));
    _options = {
      for (final name in _prefs.getStringList(_kOptions) ?? const <String>[])
        for (final o in OptionalFeature.values)
          if (o.name == name) o,
    };
    final raw = _prefs.getString(_kFarm);
    _farm = raw == null ? FarmProfile() : FarmProfile.fromJson((jsonDecode(raw) as Map).cast());
  }

  static const _kProduction = 'nafa.production';
  static const _kOptions = 'nafa.options';
  static const _kFarm = 'nafa.farm.v1';

  final SharedPreferences _prefs;
  ProductionType? _production;
  Set<OptionalFeature> _options = {};
  late FarmProfile _farm;

  FarmProfile get farm => _farm;

  Future<void> setFarm(FarmProfile farm) async {
    _farm = farm;
    await _prefs.setString(_kFarm, jsonEncode(farm.toJson()));
    notifyListeners();
  }

  static Future<FarmSettings> load() async =>
      FarmSettings(await SharedPreferences.getInstance());

  ProductionType? get production => _production;
  Set<OptionalFeature> get options => Set.unmodifiable(_options);
  bool get isConfigured => _production != null;

  List<AppModule> get modules =>
      _production == null ? const [] : modulesFor(_production!, options: _options);

  Future<void> choose(ProductionType production, Set<OptionalFeature> options) async {
    // On ne garde que les options valables pour cette production.
    final allowed = optionsFor(production).toSet();
    _production = production;
    _options = options.intersection(allowed);
    await _prefs.setString(_kProduction, production.name);
    await _prefs.setStringList(_kOptions, _options.map((o) => o.name).toList());
    notifyListeners();
  }

  Future<void> setOption(OptionalFeature option, bool enabled) async {
    if (_production == null || !optionsFor(_production!).contains(option)) return;
    enabled ? _options.add(option) : _options.remove(option);
    await _prefs.setStringList(_kOptions, _options.map((o) => o.name).toList());
    notifyListeners();
  }

  Future<void> reset() async {
    _production = null;
    _options = {};
    await _prefs.remove(_kProduction);
    await _prefs.remove(_kOptions);
    notifyListeners();
  }
}
