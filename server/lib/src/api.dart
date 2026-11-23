import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'permissions.dart';
import 'schema.dart';

/// Erreur renvoyée au client avec un message en français.
class ApiError implements Exception {
  ApiError(this.status, this.message);
  final int status;
  final String message;
}

/// API du serveur Nafa Élevage.
class NafaApi {
  NafaApi(this.db, {this.sessionDays = 90, this.bcryptRounds = 10});

  final Pool<void> db;
  final int sessionDays;
  final int bcryptRounds;
  final _rand = Random.secure();

  /// Crée les tables si besoin.
  Future<void> migrate() async {
    for (final stmt in schemaSql.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
      await db.execute(stmt);
    }
  }

  Handler get handler {
    final r = Router()
      ..get('/sante', (Request _) => _json({'ok': true}))
      ..post('/auth/inscription', _wrap(_register))
      ..post('/auth/connexion', _wrap(_login))
      ..post('/auth/deconnexion', _wrap(_logout))
      ..get('/moi', _wrap(_me))
      ..post('/fermes', _wrap(_createFarm))
      ..get('/fermes/<id>/membres', _wrap1(_members))
      ..post('/fermes/<id>/membres', _wrap1(_addMember))
      ..delete('/fermes/<id>/membres/<userId>', _wrap2(_removeMember))
      ..get('/fermes/<id>/donnees', _wrap1(_pull))
      ..post('/fermes/<id>/donnees', _wrap1(_push));
    return const Pipeline().addMiddleware(_cors()).addHandler(r.call);
  }

  // ───────────────────────────── Comptes ─────────────────────────────

  static String normalizePhone(String raw) {
    final p = raw.replaceAll(RegExp(r'[\s.\-()]'), '');
    if (!RegExp(r'^\+?\d{8,15}$').hasMatch(p)) {
      throw ApiError(400, 'Numéro de téléphone invalide (au moins 8 chiffres).');
    }
    return p;
  }

  Future<Response> _register(Request req) async {
    final b = await _body(req);
    final phone = normalizePhone(b['telephone'] as String? ?? '');
    final name = (b['nom'] as String? ?? '').trim();
    final password = b['motDePasse'] as String? ?? '';
    if (name.isEmpty) throw ApiError(400, 'Indiquez votre nom.');
    if (password.length < 6) throw ApiError(400, 'Le mot de passe doit avoir au moins 6 caractères.');
    final hash = BCrypt.hashpw(password, BCrypt.gensalt(logRounds: bcryptRounds));
    final Result rows;
    try {
      rows = await db.execute(
        Sql.named('INSERT INTO users (phone, name, password_hash) VALUES (@p, @n, @h) RETURNING id'),
        parameters: {'p': phone, 'n': name, 'h': hash},
      );
    } on ServerException catch (e) {
      if (e.code == '23505') throw ApiError(409, 'Un compte existe déjà avec ce numéro.');
      rethrow;
    }
    final id = rows.first[0]! as int;
    return _json({'jeton': await _newSession(id), 'utilisateur': {'id': id, 'nom': name, 'telephone': phone}}, 201);
  }

  Future<Response> _login(Request req) async {
    final b = await _body(req);
    final phone = normalizePhone(b['telephone'] as String? ?? '');
    final rows = await db.execute(Sql.named('SELECT id, name, password_hash FROM users WHERE phone = @p'),
        parameters: {'p': phone});
    // Même message si le compte n'existe pas : on ne révèle pas quels numéros sont inscrits.
    if (rows.isEmpty || !BCrypt.checkpw(b['motDePasse'] as String? ?? '', rows.first[2]! as String)) {
      throw ApiError(401, 'Numéro ou mot de passe incorrect.');
    }
    final id = rows.first[0]! as int;
    return _json({'jeton': await _newSession(id), 'utilisateur': {'id': id, 'nom': rows.first[1], 'telephone': phone}});
  }

  Future<Response> _logout(Request req) async {
    await db.execute(Sql.named('DELETE FROM sessions WHERE token_hash = @t'), parameters: {'t': _hash(_token(req))});
    return _json({'ok': true});
  }

  Future<Response> _me(Request req) async {
    final u = await _user(req);
    final farms = await db.execute(
      Sql.named('SELECT f.id, f.name, f.location, m.role FROM memberships m JOIN farms f ON f.id = m.farm_id '
          'WHERE m.user_id = @u ORDER BY f.id'),
      parameters: {'u': u.id},
    );
    return _json({
      'utilisateur': {'id': u.id, 'nom': u.name, 'telephone': u.phone},
      'fermes': [
        for (final r in farms) {'id': r[0], 'nom': r[1], 'lieu': r[2], 'role': r[3]},
      ],
    });
  }

  Future<String> _newSession(int userId) async {
    final token = base64Url.encode(List<int>.generate(32, (_) => _rand.nextInt(256))).replaceAll('=', '');
    await db.execute(
      Sql.named("INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (@t, @u, now() + make_interval(days => @d))"),
      parameters: {'t': _hash(token), 'u': userId, 'd': sessionDays},
    );
    return token;
  }

  // ───────────────────────────── Fermes ─────────────────────────────

  Future<Response> _createFarm(Request req) async {
    final u = await _user(req);
    final b = await _body(req);
    final name = (b['nom'] as String? ?? '').trim();
    if (name.isEmpty) throw ApiError(400, 'Indiquez le nom de la ferme.');
    final id = await db.runTx((tx) async {
      final r = await tx.execute(Sql.named('INSERT INTO farms (name, location) VALUES (@n, @l) RETURNING id'),
          parameters: {'n': name, 'l': (b['lieu'] as String? ?? '').trim()});
      final fid = r.first[0]! as int;
      await tx.execute(Sql.named("INSERT INTO memberships (farm_id, user_id, role) VALUES (@f, @u, 'proprietaire')"),
          parameters: {'f': fid, 'u': u.id});
      return fid;
    });
    return _json({'id': id, 'nom': name, 'role': 'proprietaire'}, 201);
  }

  Future<Response> _members(Request req, String id) async {
    final u = await _user(req);
    await _role(u.id, int.parse(id));
    final rows = await db.execute(
      Sql.named('SELECT u.id, u.name, u.phone, m.role FROM memberships m JOIN users u ON u.id = m.user_id '
          'WHERE m.farm_id = @f ORDER BY u.name'),
      parameters: {'f': int.parse(id)},
    );
    return _json({
      'membres': [
        for (final r in rows) {'id': r[0], 'nom': r[1], 'telephone': r[2], 'role': r[3]},
      ],
    });
  }

  /// Ajoute (ou change le rôle d') une personne qui a déjà un compte.
  Future<Response> _addMember(Request req, String id) async {
    final u = await _user(req);
    final farm = int.parse(id);
    final actor = await _role(u.id, farm);
    final b = await _body(req);
    final role = b['role'] as String? ?? '';
    if (!roles.contains(role)) throw ApiError(400, 'Rôle inconnu.');
    if (!canManageMembers(actor) || !canGrant(actor, role)) {
      throw ApiError(403, 'Votre rôle ne permet pas de donner ce rôle.');
    }
    final phone = normalizePhone(b['telephone'] as String? ?? '');
    final rows = await db.execute(Sql.named('SELECT id, name FROM users WHERE phone = @p'), parameters: {'p': phone});
    if (rows.isEmpty) throw ApiError(404, 'Aucun compte avec ce numéro : la personne doit d’abord créer son compte.');
    final memberId = rows.first[0]! as int;
    if (memberId == u.id) throw ApiError(400, 'Vous ne pouvez pas changer votre propre rôle.');
    await db.execute(
      Sql.named('INSERT INTO memberships (farm_id, user_id, role) VALUES (@f, @u, @r) '
          'ON CONFLICT (farm_id, user_id) DO UPDATE SET role = EXCLUDED.role'),
      parameters: {'f': farm, 'u': memberId, 'r': role},
    );
    return _json({'id': memberId, 'nom': rows.first[1], 'telephone': phone, 'role': role});
  }

  Future<Response> _removeMember(Request req, String id, String userId) async {
    final u = await _user(req);
    final farm = int.parse(id);
    final actor = await _role(u.id, farm);
    final target = int.parse(userId);
    final rows = await db.execute(Sql.named('SELECT role FROM memberships WHERE farm_id = @f AND user_id = @u'),
        parameters: {'f': farm, 'u': target});
    if (rows.isEmpty) throw ApiError(404, 'Cette personne n’est pas membre de la ferme.');
    if (target == u.id || !canManageMembers(actor) || !canGrant(actor, rows.first[0]! as String)) {
      throw ApiError(403, 'Votre rôle ne permet pas de retirer cette personne.');
    }
    await db.execute(Sql.named('DELETE FROM memberships WHERE farm_id = @f AND user_id = @u'),
        parameters: {'f': farm, 'u': target});
    return _json({'ok': true});
  }

  // ─────────────────────────── Données ───────────────────────────

  /// Données modifiées depuis la version [depuis] (0 = tout).
  Future<Response> _pull(Request req, String id) async {
    final u = await _user(req);
    final farm = int.parse(id);
    final role = await _role(u.id, farm);
    final since = int.tryParse(req.url.queryParameters['depuis'] ?? '0') ?? 0;
    final rows = await db.execute(
      Sql.named('SELECT key, value, version FROM farm_data WHERE farm_id = @f AND version > @v ORDER BY version'),
      parameters: {'f': farm, 'v': since},
    );
    final v = await db.execute(Sql.named('SELECT data_version FROM farms WHERE id = @f'), parameters: {'f': farm});
    return _json({
      'version': v.first[0],
      'role': role,
      'elements': [
        for (final r in rows) {'cle': r[0], 'valeur': r[1], 'version': r[2]},
      ],
    });
  }

  /// Envoi de modifications. Chaque élément porte la version sur laquelle
  /// il a été modifié (`versionBase`). Si quelqu'un a modifié la même donnée
  /// entre-temps, l'élément est refusé (conflit) et la version du serveur
  /// est renvoyée : le téléphone fusionne puis renvoie.
  Future<Response> _push(Request req, String id) async {
    final u = await _user(req);
    final farm = int.parse(id);
    final role = await _role(u.id, farm);
    final b = await _body(req);
    final items = (b['elements'] as List? ?? const []).cast<Map>();
    final accepted = <Map<String, Object?>>[];
    final conflicts = <Map<String, Object?>>[];
    final forbidden = <String>[];
    final version = await db.runTx((tx) async {
      // Verrou sur la ferme : les envois d'une même ferme passent l'un après l'autre.
      final f = await tx.execute(Sql.named('SELECT data_version FROM farms WHERE id = @f FOR UPDATE'),
          parameters: {'f': farm});
      var v = f.first[0]! as int;
      for (final it in items) {
        final key = it['cle'] as String? ?? '';
        final value = it['valeur'];
        final base = it['versionBase'] as int? ?? 0;
        if (!syncedKeys.contains(key) || value is! String) {
          throw ApiError(400, 'Donnée inconnue : $key');
        }
        if (!canWrite(role, key)) {
          forbidden.add(key);
          continue;
        }
        final cur = await tx.execute(Sql.named('SELECT value, version FROM farm_data WHERE farm_id = @f AND key = @k'),
            parameters: {'f': farm, 'k': key});
        final curVersion = cur.isEmpty ? 0 : cur.first[1]! as int;
        if (curVersion != base) {
          conflicts.add({'cle': key, 'valeur': cur.first[0], 'version': curVersion});
          continue;
        }
        v++;
        await tx.execute(
          Sql.named('INSERT INTO farm_data (farm_id, key, value, version, updated_by) VALUES (@f, @k, @val, @v, @u) '
              'ON CONFLICT (farm_id, key) DO UPDATE SET value = EXCLUDED.value, version = EXCLUDED.version, '
              'updated_at = now(), updated_by = EXCLUDED.updated_by'),
          parameters: {'f': farm, 'k': key, 'val': value, 'v': v, 'u': u.id},
        );
        accepted.add({'cle': key, 'version': v});
      }
      await tx.execute(Sql.named('UPDATE farms SET data_version = @v WHERE id = @f'), parameters: {'v': v, 'f': farm});
      return v;
    });
    return _json({'version': version, 'acceptes': accepted, 'conflits': conflicts, 'interdits': forbidden});
  }

  // ───────────────────────────── Outils ─────────────────────────────

  Future<({int id, String name, String phone})> _user(Request req) async {
    final rows = await db.execute(
      Sql.named('SELECT u.id, u.name, u.phone FROM sessions s JOIN users u ON u.id = s.user_id '
          'WHERE s.token_hash = @t AND s.expires_at > now()'),
      parameters: {'t': _hash(_token(req))},
    );
    if (rows.isEmpty) throw ApiError(401, 'Session expirée : reconnectez-vous.');
    return (id: rows.first[0]! as int, name: rows.first[1]! as String, phone: rows.first[2]! as String);
  }

  Future<String> _role(int userId, int farmId) async {
    final rows = await db.execute(Sql.named('SELECT role FROM memberships WHERE farm_id = @f AND user_id = @u'),
        parameters: {'f': farmId, 'u': userId});
    if (rows.isEmpty) throw ApiError(403, 'Vous n’êtes pas membre de cette ferme.');
    return rows.first[0]! as String;
  }

  String _token(Request req) {
    final h = req.headers['authorization'] ?? '';
    if (!h.startsWith('Bearer ')) throw ApiError(401, 'Connexion requise.');
    return h.substring(7);
  }

  static String _hash(String token) => sha256.convert(utf8.encode(token)).toString();

  Future<Map<String, Object?>> _body(Request req) async {
    try {
      final j = jsonDecode(await req.readAsString());
      if (j is Map<String, Object?>) return j;
    } catch (_) {}
    throw ApiError(400, 'Requête invalide.');
  }

  // Une enveloppe par nombre de paramètres d'adresse (le routeur les passe
  // selon la signature de la fonction).
  Handler _wrap(Future<Response> Function(Request) f) => (req) => _guard(() => f(req));
  Future<Response> Function(Request, String) _wrap1(Future<Response> Function(Request, String) f) =>
      (req, a) => _guard(() => f(req, a));
  Future<Response> Function(Request, String, String) _wrap2(Future<Response> Function(Request, String, String) f) =>
      (req, a, b) => _guard(() => f(req, a, b));

  Future<Response> _guard(Future<Response> Function() run) async {
    try {
      return await run();
    } on ApiError catch (e) {
      return _json({'erreur': e.message}, e.status);
    } on FormatException {
      return _json({'erreur': 'Requête invalide.'}, 400);
    }
  }

  static Response _json(Object body, [int status = 200]) => Response(status,
      body: jsonEncode(body), headers: {'content-type': 'application/json; charset=utf-8'});

  /// L'application web appelle le serveur depuis une autre adresse.
  Middleware _cors() => (inner) => (req) async {
        const h = {
          'access-control-allow-origin': '*',
          'access-control-allow-methods': 'GET, POST, DELETE, OPTIONS',
          'access-control-allow-headers': 'authorization, content-type',
        };
        if (req.method == 'OPTIONS') return Response.ok('', headers: h);
        final res = await inner(req);
        return res.change(headers: h);
      };
}
