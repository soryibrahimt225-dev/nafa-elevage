import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/format.dart';
import '../domain/production.dart';
import 'app_data.dart';

/// Contenu résumé d'un fichier de sauvegarde (affiché avant restauration).
class BackupInfo {
  const BackupInfo({
    required this.createdAt,
    required this.farmName,
    required this.production,
    required this.animalLots,
    required this.incubationLots,
    required this.sales,
    required this.expenses,
  });

  final DateTime createdAt;
  final String farmName;
  final ProductionType? production;
  final int animalLots, incubationLots, sales, expenses;

  String get summary => [
        if (farmName.isNotEmpty) farmName,
        if (production != null) production!.label,
        'sauvegarde du ${formatDate(createdAt)}',
        '${formatInt(animalLots)} lot(s) de sujets',
        '${formatInt(incubationLots)} lot(s) d’œufs',
        '${formatInt(sales)} vente(s)',
        '${formatInt(expenses)} dépense(s)',
      ].join(' · ');
}

/// Sauvegarde complète dans un fichier et restauration.
///
/// Le fichier contient toutes les données enregistrées sur l'appareil.
/// Il n'emporte pas les rappels d'agenda (propres à chaque téléphone) :
/// après une restauration, on les recrée depuis Paramètres.
class BackupService {
  BackupService(this._prefs, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const app = 'nafa-elevage';
  static const format = 1;
  static const _prefix = 'nafa.';
  static const _lastAt = 'nafa.backup.lastAt';
  static const _previous = 'nafa.backup.previous';

  /// Clés jamais sauvegardées : rappels du téléphone et gestion des
  /// sauvegardes elles-mêmes.
  static const _excluded = {'nafa.reminders.v1', 'nafa.sync.v1', _lastAt, _previous};

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  static Future<BackupService> load() async => BackupService(await SharedPreferences.getInstance());

  DateTime? get lastBackupAt {
    final s = _prefs.getString(_lastAt);
    return s == null ? null : DateTime.tryParse(s);
  }

  bool get canUndoRestore => _prefs.getString(_previous) != null;

  Map<String, Object> _snapshot() => {
        for (final k in _prefs.getKeys())
          if (k.startsWith(_prefix) && !_excluded.contains(k))
            if (_prefs.get(k) case final Object v) k: v,
      };

  /// Crée le fichier de sauvegarde (JSON, UTF-8).
  Future<Uint8List> export() async {
    final now = _clock();
    final file = {
      'app': app,
      'format': format,
      'createdAt': now.toIso8601String(),
      'data': {for (final e in _snapshot().entries) e.key: _encode(e.value)},
    };
    await _prefs.setString(_lastAt, now.toIso8601String());
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent(' ').convert(file)));
  }

  /// Nom de fichier proposé : `nafa-sauvegarde-ferme-AAAA-MM-JJ.json`.
  String fileName(String farmName) {
    final d = _clock();
    final slug = farmName
        .toLowerCase()
        .replaceAll(RegExp('[àâä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[îï]'), 'i')
        .replaceAll(RegExp('[ôö]'), 'o')
        .replaceAll(RegExp('[ùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'nafa-sauvegarde${slug.isEmpty ? '' : '-$slug'}-$date.json';
  }

  /// Lit et vérifie un fichier ; erreur claire s'il n'est pas valable.
  BackupInfo inspect(Uint8List bytes) {
    final data = _parse(bytes).$2;
    int count(String key, String field) {
      final raw = data[key];
      if (raw is! String) return 0;
      final j = jsonDecode(raw);
      return j is Map && j[field] is List ? (j[field] as List).length : 0;
    }

    final farm = data['nafa.farm.v1'];
    return BackupInfo(
      createdAt: _parse(bytes).$1,
      farmName: farm is String ? ((jsonDecode(farm) as Map)['name'] as String? ?? '') : '',
      production: ProductionType.fromName(data['nafa.production'] as String?),
      animalLots: count('nafa.lots.v1', 'animal'),
      incubationLots: count('nafa.lots.v1', 'incubation'),
      sales: count('nafa.finance.v1', 'sales'),
      expenses: count('nafa.finance.v1', 'expenses'),
    );
  }

  /// Remplace toutes les données par celles du fichier. Les données
  /// actuelles sont gardées pour pouvoir annuler. Si le fichier ne peut pas
  /// être relu par l'application, rien n'est changé.
  Future<void> restore(Uint8List bytes) async {
    final data = _parse(bytes).$2;
    final current = _snapshot();
    await _prefs.setString(_previous, jsonEncode({for (final e in current.entries) e.key: _encode(e.value)}));
    await _replaceWith(data);
    try {
      await AppData.load(); // vérifie que tout se relit
    } catch (_) {
      await _replaceWith({for (final e in current.entries) e.key: _encode(e.value)});
      await _prefs.remove(_previous);
      throw const FormatException('Le fichier est abîmé : il ne peut pas être relu. Aucune donnée n’a été changée.');
    }
  }

  /// Efface toutes les données de l'application sur cet appareil
  /// (recommencer à zéro). Le compte de synchronisation est aussi oublié.
  Future<void> resetAll() async {
    for (final k in _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await _prefs.remove(k);
    }
  }

  /// Revient aux données d'avant la dernière restauration.
  Future<void> undoRestore() async {
    final raw = _prefs.getString(_previous);
    if (raw == null) return;
    await _replaceWith((jsonDecode(raw) as Map).cast<String, Object?>());
    await _prefs.remove(_previous);
  }

  Future<void> _replaceWith(Map<String, Object?> data) async {
    for (final k in _snapshot().keys) {
      await _prefs.remove(k);
    }
    for (final e in data.entries) {
      if (!e.key.startsWith(_prefix) || _excluded.contains(e.key)) continue;
      final v = _decode(e.value);
      switch (v) {
        case String s:
          await _prefs.setString(e.key, s);
        case bool b:
          await _prefs.setBool(e.key, b);
        case int i:
          await _prefs.setInt(e.key, i);
        case double d:
          await _prefs.setDouble(e.key, d);
        case List<String> l:
          await _prefs.setStringList(e.key, l);
      }
    }
  }

  (DateTime, Map<String, Object?>) _parse(Uint8List bytes) {
    final Object? j;
    try {
      j = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('Ce fichier n’est pas une sauvegarde Nafa Élevage.');
    }
    if (j is! Map || j['app'] != app || j['data'] is! Map) {
      throw const FormatException('Ce fichier n’est pas une sauvegarde Nafa Élevage.');
    }
    final f = j['format'];
    if (f is! int || f > format) {
      throw const FormatException('Cette sauvegarde vient d’une version plus récente de Nafa : mettez l’application à jour.');
    }
    final created = DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime(2000);
    return (created, (j['data'] as Map).cast<String, Object?>());
  }

  // Les listes de textes sont marquées pour être relues comme telles.
  static Object? _encode(Object v) => v is List ? {'list': v} : v;
  static Object? _decode(Object? v) => v is Map && v['list'] is List ? (v['list'] as List).cast<String>().toList() : v;
}
