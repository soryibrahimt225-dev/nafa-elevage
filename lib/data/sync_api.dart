import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erreur du serveur, avec un message en français à montrer.
class SyncException implements Exception {
  SyncException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class RemoteUser {
  const RemoteUser(this.id, this.name, this.phone);
  final int id;
  final String name;
  final String phone;
}

class RemoteFarm {
  const RemoteFarm(this.id, this.name, this.role);
  final int id;
  final String name;
  final String role;
}

class RemoteMember {
  const RemoteMember(this.id, this.name, this.phone, this.role);
  final int id;
  final String name;
  final String phone;
  final String role;
}

class RemoteItem {
  const RemoteItem(this.key, this.value, this.version);
  final String key;
  final String value;
  final int version;
}

class PullResult {
  const PullResult(this.version, this.role, this.items);
  final int version;
  final String role;
  final List<RemoteItem> items;
}

class PushResult {
  const PushResult(this.version, this.accepted, this.conflicts, this.forbidden);
  final int version;

  /// Clé → nouvelle version.
  final Map<String, int> accepted;
  final List<RemoteItem> conflicts;
  final List<String> forbidden;
}

/// Accès au serveur Nafa Élevage (comptes, fermes, données).
abstract class SyncApi {
  Future<(String token, RemoteUser user)> register(String phone, String name, String password);
  Future<(String token, RemoteUser user)> login(String phone, String password);
  Future<void> logout(String token);
  Future<(RemoteUser, List<RemoteFarm>)> me(String token);
  Future<RemoteFarm> createFarm(String token, String name, String location);
  Future<List<RemoteMember>> members(String token, int farm);
  Future<void> addMember(String token, int farm, String phone, String role);
  Future<void> removeMember(String token, int farm, int userId);
  Future<PullResult> pull(String token, int farm, int since);
  Future<PushResult> push(String token, int farm, List<(String key, String value, int baseVersion)> items);
}

class HttpSyncApi implements SyncApi {
  HttpSyncApi(String baseUrl, {http.Client? client})
      : base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _client = client ?? http.Client();

  final Uri base;
  final http.Client _client;

  Future<Map<String, dynamic>> _call(String method, String path, {String? token, Object? body}) async {
    final http.Response res;
    try {
      final req = http.Request(method, base.resolve(path))
        ..headers['content-type'] = 'application/json'
        ..headers.addAll({if (token != null) 'authorization': 'Bearer $token'});
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 30)));
    } catch (_) {
      throw SyncException('Serveur injoignable : vérifiez la connexion internet et l’adresse du serveur.');
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw SyncException('Réponse inattendue du serveur (code ${res.statusCode}).', status: res.statusCode);
    }
    if (res.statusCode >= 400) {
      throw SyncException(j['erreur'] as String? ?? 'Erreur du serveur (code ${res.statusCode}).', status: res.statusCode);
    }
    return j;
  }

  RemoteUser _user(Map j) => RemoteUser(j['id'] as int, j['nom'] as String, j['telephone'] as String);

  @override
  Future<(String, RemoteUser)> register(String phone, String name, String password) async {
    final j = await _call('POST', 'auth/inscription', body: {'telephone': phone, 'nom': name, 'motDePasse': password});
    return (j['jeton'] as String, _user(j['utilisateur'] as Map));
  }

  @override
  Future<(String, RemoteUser)> login(String phone, String password) async {
    final j = await _call('POST', 'auth/connexion', body: {'telephone': phone, 'motDePasse': password});
    return (j['jeton'] as String, _user(j['utilisateur'] as Map));
  }

  @override
  Future<void> logout(String token) => _call('POST', 'auth/deconnexion', token: token);

  @override
  Future<(RemoteUser, List<RemoteFarm>)> me(String token) async {
    final j = await _call('GET', 'moi', token: token);
    return (
      _user(j['utilisateur'] as Map),
      [for (final f in j['fermes'] as List) RemoteFarm(f['id'] as int, f['nom'] as String, f['role'] as String)],
    );
  }

  @override
  Future<RemoteFarm> createFarm(String token, String name, String location) async {
    final j = await _call('POST', 'fermes', token: token, body: {'nom': name, 'lieu': location});
    return RemoteFarm(j['id'] as int, j['nom'] as String, j['role'] as String);
  }

  @override
  Future<List<RemoteMember>> members(String token, int farm) async {
    final j = await _call('GET', 'fermes/$farm/membres', token: token);
    return [
      for (final m in j['membres'] as List)
        RemoteMember(m['id'] as int, m['nom'] as String, m['telephone'] as String, m['role'] as String),
    ];
  }

  @override
  Future<void> addMember(String token, int farm, String phone, String role) =>
      _call('POST', 'fermes/$farm/membres', token: token, body: {'telephone': phone, 'role': role});

  @override
  Future<void> removeMember(String token, int farm, int userId) =>
      _call('DELETE', 'fermes/$farm/membres/$userId', token: token);

  @override
  Future<PullResult> pull(String token, int farm, int since) async {
    final j = await _call('GET', 'fermes/$farm/donnees?depuis=$since', token: token);
    return PullResult(j['version'] as int, j['role'] as String, [
      for (final e in j['elements'] as List) RemoteItem(e['cle'] as String, e['valeur'] as String, e['version'] as int),
    ]);
  }

  @override
  Future<PushResult> push(String token, int farm, List<(String, String, int)> items) async {
    final j = await _call('POST', 'fermes/$farm/donnees', token: token, body: {
      'elements': [
        for (final (k, v, b) in items) {'cle': k, 'valeur': v, 'versionBase': b},
      ],
    });
    return PushResult(
      j['version'] as int,
      {for (final a in j['acceptes'] as List) a['cle'] as String: a['version'] as int},
      [for (final c in j['conflits'] as List) RemoteItem(c['cle'] as String, c['valeur'] as String, c['version'] as int)],
      (j['interdits'] as List).cast<String>(),
    );
  }
}
