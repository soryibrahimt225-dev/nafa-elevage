import 'package:nafa_elevage/data/sync_api.dart';

/// Serveur simulé en mémoire (mêmes règles de version que le vrai).
class FakeSyncApi implements SyncApi {
  final users = <String, (int, String, String)>{}; // téléphone → (id, nom, mot de passe)
  final data = <String, (String, int)>{};
  var version = 0;
  var farmCreated = false;

  @override
  Future<(String, RemoteUser)> register(String phone, String name, String password) async {
    if (password.length < 6) throw SyncException('Le mot de passe doit avoir au moins 6 caractères.');
    users[phone] = (users.length + 1, name, password);
    return ('jeton-$phone', RemoteUser(users.length, name, phone));
  }

  @override
  Future<(String, RemoteUser)> login(String phone, String password) async {
    final u = users[phone];
    if (u == null || u.$3 != password) throw SyncException('Numéro ou mot de passe incorrect.', status: 401);
    return ('jeton-$phone', RemoteUser(u.$1, u.$2, phone));
  }

  @override
  Future<void> logout(String token) async {}
  @override
  Future<(RemoteUser, List<RemoteFarm>)> me(String token) async =>
      (const RemoteUser(1, 'x', 'x'), [if (farmCreated) const RemoteFarm(1, 'Ferme', 'proprietaire')]);
  @override
  Future<RemoteFarm> createFarm(String token, String name, String location) async {
    farmCreated = true;
    return RemoteFarm(1, name, 'proprietaire');
  }

  @override
  Future<List<RemoteMember>> members(String token, int farm) async => [];
  @override
  Future<void> addMember(String token, int farm, String phone, String role) async {}
  @override
  Future<void> removeMember(String token, int farm, int userId) async {}

  @override
  Future<PullResult> pull(String token, int farm, int since) async => PullResult(version, 'proprietaire', [
        for (final e in data.entries)
          if (e.value.$2 > since) RemoteItem(e.key, e.value.$1, e.value.$2),
      ]);

  @override
  Future<PushResult> push(String token, int farm, List<(String, String, int)> items) async {
    final ok = <String, int>{};
    final conflicts = <RemoteItem>[];
    for (final (k, v, b) in items) {
      final cur = data[k]?.$2 ?? 0;
      if (cur != b) {
        conflicts.add(RemoteItem(k, data[k]!.$1, cur));
        continue;
      }
      data[k] = (v, ++version);
      ok[k] = version;
    }
    return PushResult(version, ok, conflicts, const []);
  }
}
