import 'dart:convert';
import 'dart:io';

import 'package:nafa_server/nafa_server.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Tests contre un vrai PostgreSQL : TEST_DATABASE_URL
/// (ex. postgresql://postgres@localhost:5433/nafa_test?sslmode=disable).
void main() {
  final url = Platform.environment['TEST_DATABASE_URL'];
  if (url == null) {
    test('PostgreSQL non configuré', () {}, skip: 'TEST_DATABASE_URL absent');
    return;
  }

  late Pool<void> pool;
  late NafaApi api;
  late Handler h;

  setUp(() async {
    pool = Pool.withUrl(url);
    await pool.execute('DROP TABLE IF EXISTS farm_data, memberships, sessions, farms, users CASCADE');
    api = NafaApi(pool, bcryptRounds: 4); // rapide pour les tests
    await api.migrate();
    h = api.handler;
  });
  tearDown(() => pool.close());

  Future<(int, Map<String, dynamic>)> call(String method, String path, {Object? body, String? token}) async {
    final res = await h(Request(method, Uri.parse('http://localhost$path'),
        body: body == null ? null : jsonEncode(body),
        headers: {if (token != null) 'authorization': 'Bearer $token'}));
    final text = await res.readAsString();
    return (res.statusCode, text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>);
  }

  Future<String> register(String phone, String name) async {
    final (s, b) = await call('POST', '/auth/inscription', body: {'telephone': phone, 'nom': name, 'motDePasse': 'secret123'});
    expect(s, 201, reason: '$b');
    return b['jeton'] as String;
  }

  group('Comptes', () {
    test('inscription, connexion, moi, déconnexion', () async {
      final t = await register('76 12 34 56', 'Sory');
      final (s1, me) = await call('GET', '/moi', token: t);
      expect(s1, 200);
      expect(me['utilisateur']['telephone'], '76123456'); // espaces retirés
      final (s2, login) = await call('POST', '/auth/connexion', body: {'telephone': '76123456', 'motDePasse': 'secret123'});
      expect(s2, 200);
      expect(login['jeton'], isNot(t));
      await call('POST', '/auth/deconnexion', token: t);
      expect((await call('GET', '/moi', token: t)).$1, 401);
    });
    test('erreurs claires', () async {
      await register('76123456', 'Sory');
      expect((await call('POST', '/auth/inscription', body: {'telephone': '76123456', 'nom': 'X', 'motDePasse': 'secret123'})).$2['erreur'],
          contains('existe déjà'));
      expect((await call('POST', '/auth/inscription', body: {'telephone': '123', 'nom': 'X', 'motDePasse': 'secret123'})).$1, 400);
      expect((await call('POST', '/auth/inscription', body: {'telephone': '76000000', 'nom': 'X', 'motDePasse': '123'})).$2['erreur'],
          contains('6 caractères'));
      final bad = await call('POST', '/auth/connexion', body: {'telephone': '76123456', 'motDePasse': 'mauvais'});
      expect(bad.$1, 401);
      final unknown = await call('POST', '/auth/connexion', body: {'telephone': '79999999', 'motDePasse': 'secret123'});
      expect(unknown.$2['erreur'], bad.$2['erreur']); // ne révèle pas les numéros inscrits
      expect((await call('GET', '/moi')).$1, 401);
    });
    test('mot de passe jamais stocké en clair', () async {
      await register('76123456', 'Sory');
      final r = await pool.execute('SELECT password_hash FROM users');
      expect(r.first[0], isNot('secret123'));
      expect(r.first[0] as String, startsWith(r'$2'));
    });
  });

  group('Fermes et rôles', () {
    test('le créateur est propriétaire ; ajout de membres', () async {
      final owner = await register('76123456', 'Sory');
      final emp = await register('66111111', 'Awa');
      final (s, farm) = await call('POST', '/fermes', body: {'nom': 'Ferme de Kati', 'lieu': 'Kati'}, token: owner);
      expect(s, 201);
      final id = farm['id'];
      expect((await call('POST', '/fermes/$id/membres', body: {'telephone': '66111111', 'role': 'employe'}, token: owner)).$1, 200);
      final (_, me) = await call('GET', '/moi', token: emp);
      expect(me['fermes'].single['role'], 'employe');
      // L'employé ne gère pas les membres
      expect((await call('POST', '/fermes/$id/membres', body: {'telephone': '76123456', 'role': 'employe'}, token: emp)).$1, 403);
      // Numéro sans compte
      expect((await call('POST', '/fermes/$id/membres', body: {'telephone': '70000000', 'role': 'comptable'}, token: owner)).$2['erreur'],
          contains('créer son compte'));
      final (_, m) = await call('GET', '/fermes/$id/membres', token: owner);
      expect((m['membres'] as List).length, 2);
    });
    test('un non-membre ne voit rien', () async {
      final owner = await register('76123456', 'Sory');
      final other = await register('66111111', 'Awa');
      final (_, farm) = await call('POST', '/fermes', body: {'nom': 'Ferme'}, token: owner);
      expect((await call('GET', '/fermes/${farm['id']}/donnees', token: other)).$1, 403);
    });
    test('un gestionnaire ne peut pas nommer de propriétaire', () async {
      final owner = await register('76123456', 'Sory');
      final g = await register('66111111', 'Awa');
      await register('70111111', 'Moussa');
      final (_, farm) = await call('POST', '/fermes', body: {'nom': 'Ferme'}, token: owner);
      await call('POST', '/fermes/${farm['id']}/membres', body: {'telephone': '66111111', 'role': 'gestionnaire'}, token: owner);
      expect((await call('POST', '/fermes/${farm['id']}/membres', body: {'telephone': '70111111', 'role': 'proprietaire'}, token: g)).$1,
          403);
      expect((await call('POST', '/fermes/${farm['id']}/membres', body: {'telephone': '70111111', 'role': 'employe'}, token: g)).$1, 200);
    });
  });

  group('Synchronisation', () {
    late String owner, comptable;
    late int farm;
    setUp(() async {
      owner = await register('76123456', 'Sory');
      comptable = await register('66111111', 'Awa');
      farm = (await call('POST', '/fermes', body: {'nom': 'Ferme'}, token: owner)).$2['id'] as int;
      await call('POST', '/fermes/$farm/membres', body: {'telephone': '66111111', 'role': 'comptable'}, token: owner);
    });

    test('envoi puis réception', () async {
      final (_, push) = await call('POST', '/fermes/$farm/donnees', token: owner, body: {
        'elements': [
          {'cle': 'nafa.production', 'valeur': 'chair', 'versionBase': 0},
          {'cle': 'nafa.lots.v1', 'valeur': '{"animal":[],"incubation":[]}', 'versionBase': 0},
        ],
      });
      expect(push['version'], 2);
      expect((push['acceptes'] as List).length, 2);
      final (_, pull) = await call('GET', '/fermes/$farm/donnees?depuis=0', token: comptable);
      expect(pull['role'], 'comptable');
      expect((pull['elements'] as List).map((e) => e['cle']), ['nafa.production', 'nafa.lots.v1']);
      final (_, since) = await call('GET', '/fermes/$farm/donnees?depuis=1', token: comptable);
      expect((since['elements'] as List).single['cle'], 'nafa.lots.v1');
    });

    test('conflit : modification concurrente de la même donnée', () async {
      await call('POST', '/fermes/$farm/donnees', token: owner, body: {
        'elements': [{'cle': 'nafa.finance.v1', 'valeur': 'A', 'versionBase': 0}],
      });
      // Le comptable envoie une modification faite sur une version dépassée
      final (_, r) = await call('POST', '/fermes/$farm/donnees', token: comptable, body: {
        'elements': [{'cle': 'nafa.finance.v1', 'valeur': 'B', 'versionBase': 0}],
      });
      expect(r['acceptes'], isEmpty);
      expect(r['conflits'].single['valeur'], 'A');
      // Après fusion, il renvoie sur la bonne version
      final (_, ok) = await call('POST', '/fermes/$farm/donnees', token: comptable, body: {
        'elements': [{'cle': 'nafa.finance.v1', 'valeur': 'A+B', 'versionBase': r['conflits'].single['version']}],
      });
      expect((ok['acceptes'] as List).single['cle'], 'nafa.finance.v1');
    });

    test('droits par rôle : le comptable ne modifie que la comptabilité', () async {
      final (_, r) = await call('POST', '/fermes/$farm/donnees', token: comptable, body: {
        'elements': [
          {'cle': 'nafa.finance.v1', 'valeur': '{}', 'versionBase': 0},
          {'cle': 'nafa.lots.v1', 'valeur': '{}', 'versionBase': 0},
          {'cle': 'nafa.production', 'valeur': 'pondeuses', 'versionBase': 0},
        ],
      });
      expect((r['acceptes'] as List).map((e) => e['cle']), ['nafa.finance.v1']);
      expect(r['interdits'], ['nafa.lots.v1', 'nafa.production']);
    });

    test('donnée inconnue refusée', () async {
      final (s, _) = await call('POST', '/fermes/$farm/donnees', token: owner, body: {
        'elements': [{'cle': 'autre.cle', 'valeur': 'x', 'versionBase': 0}],
      });
      expect(s, 400);
    });
  });

  test('Droits par rôle (table)', () {
    expect(canWrite('employe', 'nafa.eggs.v1'), isTrue);
    expect(canWrite('employe', 'nafa.finance.v1'), isFalse);
    expect(canWrite('veterinaire', 'nafa.health.v1'), isTrue);
    expect(canWrite('veterinaire', 'nafa.lots.v1'), isFalse);
    expect(canWrite('gestionnaire', 'nafa.config.v1'), isTrue);
    expect(canWrite('inconnu', 'nafa.lots.v1'), isFalse);
  });
}
