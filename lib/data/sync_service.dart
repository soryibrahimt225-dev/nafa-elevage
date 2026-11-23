import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sync_merge.dart';
import 'sync_api.dart';

/// Données synchronisées avec le serveur (mêmes clés que le serveur).
const syncedKeys = [
  'nafa.production',
  'nafa.options',
  'nafa.farm.v1',
  'nafa.config.v1',
  'nafa.lots.v1',
  'nafa.finance.v1',
  'nafa.health.v1',
  'nafa.eggs.v1',
  'nafa.feed.v1',
  'nafa.weighings.v1',
];

/// Libellés des rôles (identiques au serveur).
const roleLabels = {
  'proprietaire': 'Propriétaire',
  'gestionnaire': 'Gestionnaire',
  'employe': 'Employé de terrain',
  'technicien': 'Technicien',
  'veterinaire': 'Vétérinaire',
  'comptable': 'Comptable',
};

class SyncReport {
  SyncReport({this.received = 0, this.sent = 0, this.merged = 0, this.refused = const []});
  int received, sent, merged;

  /// Données que le rôle ne permet pas de modifier (remises à la version
  /// du serveur).
  List<String> refused;

  /// Des données locales ont changé : l'application doit se recharger.
  bool get changedLocally => received > 0 || merged > 0 || refused.isNotEmpty;

  String get message {
    final parts = <String>[
      if (sent > 0) '$sent envoi(s)',
      if (received > 0) '$received réception(s)',
      if (merged > 0) '$merged fusion(s)',
    ];
    final base = parts.isEmpty ? 'Tout est à jour.' : 'Synchronisé : ${parts.join(', ')}.';
    return refused.isEmpty
        ? base
        : '$base ${refused.length} modification(s) non autorisée(s) par votre rôle ont été annulées.';
  }
}

/// Compte, ferme choisie et synchronisation des données avec le serveur.
///
/// Fonctionnement hors connexion : on travaille toujours sur les données du
/// téléphone ; « Synchroniser » reçoit les changements des autres
/// téléphones, fusionne, puis envoie les siens.
class SyncService extends ChangeNotifier {
  SyncService(this._prefs, {SyncApi Function(String url)? apiFactory, DateTime Function()? clock})
      : _apiFactory = apiFactory ?? HttpSyncApi.new,
        _clock = clock ?? DateTime.now {
    final raw = _prefs.getString(_key);
    _s = raw == null ? {} : (jsonDecode(raw) as Map).cast<String, Object?>();
  }

  static const _key = 'nafa.sync.v1';
  final SharedPreferences _prefs;
  final SyncApi Function(String url) _apiFactory;
  final DateTime Function() _clock;
  late Map<String, Object?> _s;
  bool _busy = false;

  static Future<SyncService> load() async => SyncService(await SharedPreferences.getInstance());

  String get serverUrl => _s['server'] as String? ?? '';
  String? get _token => _s['token'] as String?;
  bool get loggedIn => _token != null;
  String get userName => (_s['user'] as Map?)?['name'] as String? ?? '';
  String get userPhone => (_s['user'] as Map?)?['phone'] as String? ?? '';
  int? get farmId => _s['farmId'] as int?;
  String get farmName => _s['farmName'] as String? ?? '';
  String get role => _s['role'] as String? ?? '';
  String get roleLabel => roleLabels[role] ?? role;
  bool get canManageMembers => role == 'proprietaire' || role == 'gestionnaire';
  bool get busy => _busy;
  DateTime? get lastSyncAt => _s['lastSyncAt'] == null ? null : DateTime.tryParse(_s['lastSyncAt']! as String);

  SyncApi get _api {
    if (serverUrl.isEmpty) throw SyncException('Indiquez d’abord l’adresse du serveur.');
    return _apiFactory(serverUrl);
  }

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode(_s));
    notifyListeners();
  }

  Future<void> setServer(String url) async {
    final u = url.trim();
    if (u.isNotEmpty && !RegExp(r'^https?://').hasMatch(u)) {
      throw SyncException('L’adresse doit commencer par https:// (ou http:// pour un essai).');
    }
    _s['server'] = u;
    await _save();
  }

  // ───────────────────────────── Compte ─────────────────────────────

  Future<List<RemoteFarm>> register(String phone, String name, String password) async {
    final (token, user) = await _api.register(phone, name, password);
    return _signedIn(token, user);
  }

  Future<List<RemoteFarm>> login(String phone, String password) async {
    final (token, user) = await _api.login(phone, password);
    return _signedIn(token, user);
  }

  Future<List<RemoteFarm>> _signedIn(String token, RemoteUser user) async {
    _s['token'] = token;
    _s['user'] = {'id': user.id, 'name': user.name, 'phone': user.phone};
    await _save();
    return farms();
  }

  Future<List<RemoteFarm>> farms() async => (await _api.me(_token!)).$2;

  /// Déconnexion : les données restent sur le téléphone.
  Future<void> logout() async {
    final t = _token;
    if (t != null) {
      try {
        await _api.logout(t);
      } catch (_) {
        // Hors connexion : on se déconnecte quand même sur le téléphone.
      }
    }
    _s = {'server': serverUrl};
    await _save();
  }

  // ───────────────────────────── Ferme ─────────────────────────────

  /// Crée la ferme sur le serveur avec les données de ce téléphone.
  Future<SyncReport> createFarm(String name, String location) async {
    final f = await _api.createFarm(_token!, name, location);
    await _useFarm(f);
    return sync();
  }

  /// Rejoint une ferme existante : ses données sont fusionnées avec celles
  /// du téléphone.
  Future<SyncReport> joinFarm(RemoteFarm f) async {
    await _useFarm(f);
    return sync();
  }

  Future<void> _useFarm(RemoteFarm f) async {
    _s
      ..['farmId'] = f.id
      ..['farmName'] = f.name
      ..['role'] = f.role
      ..['lastVersion'] = 0
      ..['versions'] = <String, int>{}
      ..['bases'] = <String, String>{};
    await _save();
  }

  Future<List<RemoteMember>> members() => _api.members(_token!, farmId!);
  Future<void> addMember(String phone, String role) => _api.addMember(_token!, farmId!, phone, role);
  Future<void> removeMember(int userId) => _api.removeMember(_token!, farmId!, userId);

  // ─────────────────────────── Synchronisation ───────────────────────────

  Map<String, int> get _versions => ((_s['versions'] as Map?) ?? {}).cast<String, int>();
  Map<String, String> get _bases => ((_s['bases'] as Map?) ?? {}).cast<String, String>();

  /// Valeur locale d'une clé, en texte (la liste d'options en JSON).
  String? _local(String key) {
    final v = _prefs.get(key);
    if (v == null) return null;
    if (v is List) return jsonEncode(v);
    return v.toString();
  }

  Future<void> _setLocal(String key, String value) async {
    if (key == 'nafa.options') {
      await _prefs.setStringList(key, (jsonDecode(value) as List).cast<String>());
    } else {
      await _prefs.setString(key, value);
    }
  }

  /// Clés modifiées sur le téléphone depuis la dernière synchronisation.
  List<String> get pendingKeys {
    final bases = _bases;
    return [
      for (final k in syncedKeys)
        if (_local(k) case final String v when v != bases[k]) k,
    ];
  }

  Future<SyncReport> sync() async {
    if (_busy) return SyncReport();
    if (!loggedIn || farmId == null) throw SyncException('Connectez-vous et choisissez une ferme.');
    _busy = true;
    notifyListeners();
    try {
      final api = _api;
      final token = _token!, farm = farmId!;
      final report = SyncReport();
      final versions = _versions, bases = _bases;

      // 1. Recevoir les changements des autres téléphones.
      final pull = await api.pull(token, farm, _s['lastVersion'] as int? ?? 0);
      _s['role'] = pull.role;
      for (final it in pull.items) {
        await _integrate(it, versions, bases, report);
      }
      var last = pull.version;

      // 2. Envoyer ses propres changements (une nouvelle tentative après
      //    fusion si quelqu'un a modifié la même donnée entre-temps).
      for (var attempt = 0; attempt < 3; attempt++) {
        final pending = pendingKeys;
        if (pending.isEmpty) break;
        final values = {for (final k in pending) k: _local(k)!};
        final res = await api.push(token, farm, [for (final k in pending) (k, values[k]!, versions[k] ?? 0)]);
        for (final e in res.accepted.entries) {
          versions[e.key] = e.value;
          bases[e.key] = values[e.key]!;
          report.sent++;
        }
        for (final c in res.conflicts) {
          await _integrate(c, versions, bases, report);
        }
        for (final k in res.forbidden) {
          // Rôle sans droit d'écriture : on revient à la version du serveur.
          final b = bases[k];
          if (b != null) {
            await _setLocal(k, b);
          } else {
            await _prefs.remove(k);
          }
          report.refused = [...report.refused, k];
        }
        if (res.version > last) last = res.version;
        if (res.conflicts.isEmpty) break;
      }
      _s
        ..['versions'] = versions
        ..['bases'] = bases
        ..['lastVersion'] = last
        ..['lastSyncAt'] = _clock().toIso8601String();
      await _save();
      return report;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Intègre une donnée reçue : remplacée si rien n'a changé ici,
  /// sinon fusionnée.
  Future<void> _integrate(RemoteItem it, Map<String, int> versions, Map<String, String> bases, SyncReport r) async {
    final local = _local(it.key);
    final base = bases[it.key];
    if (local == null || local == base) {
      if (local != it.value) {
        await _setLocal(it.key, it.value);
        r.received++;
      }
    } else if (local != it.value) {
      await _setLocal(it.key, mergeValues(base, local, it.value));
      r.merged++;
    }
    bases[it.key] = it.value;
    versions[it.key] = it.version;
  }
}
