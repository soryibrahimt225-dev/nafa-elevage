import 'dart:convert';

/// Fusion à trois voies d'une donnée synchronisée.
///
/// - [base] : dernière version reçue du serveur (celle sur laquelle le
///   téléphone a travaillé), `null` si jamais synchronisée ;
/// - [local] : version actuelle du téléphone ;
/// - [remote] : version actuelle du serveur.
///
/// Règles :
/// - listes d'enregistrements (avec un `id`, ou `lotCode` + `date` pour les
///   œufs) : fusion enregistrement par enregistrement. Un ajout d'un côté
///   est gardé ; une suppression d'un côté est appliquée si l'autre côté n'a
///   pas modifié l'enregistrement ; si les deux ont modifié le même
///   enregistrement, la version du téléphone l'emporte ;
/// - objets : fusion champ par champ ;
/// - valeurs simples : la modification du téléphone l'emporte, sinon celle
///   du serveur.
String mergeValues(String? base, String local, String remote) {
  final b = base == null ? null : _tryJson(base);
  final l = _tryJson(local);
  final r = _tryJson(remote);
  if (l == _notJson || r == _notJson) {
    // Texte simple (ex. la production) : modification locale prioritaire.
    return base != null && local != base ? local : remote;
  }
  return jsonEncode(_merge(b == _notJson ? null : b, l, r, hasBase: base != null));
}

const _notJson = Object();

Object? _tryJson(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    return _notJson;
  }
}

Object? _merge(Object? base, Object? local, Object? remote, {required bool hasBase}) {
  if (_eq(local, remote)) return local;
  if (hasBase && _eq(local, base)) return remote; // seul le serveur a changé
  if (hasBase && _eq(remote, base)) return local; // seul le téléphone a changé
  if (local is Map && remote is Map) {
    final b = base is Map ? base : const {};
    return {
      for (final k in {...local.keys, ...remote.keys})
        if (local.containsKey(k) && remote.containsKey(k))
          k: _merge(b[k], local[k], remote[k], hasBase: hasBase && b.containsKey(k))
        else if (local.containsKey(k))
          if (!(hasBase && b.containsKey(k) && _eq(b[k], local[k]))) k: local[k] // supprimé côté serveur
          else ...{}
        else if (!(hasBase && b.containsKey(k) && _eq(b[k], remote[k])))
          k: remote[k], // supprimé côté téléphone sinon
    };
  }
  if (local is List && remote is List && _records(local) && _records(remote)) {
    return _mergeRecords(base is List ? base : const [], local, remote, hasBase: hasBase);
  }
  // Valeurs simples ou listes simples : le téléphone l'emporte s'il a changé
  // quelque chose depuis la base ; sans base (première fois), le serveur.
  return hasBase ? local : remote;
}

String? _id(Object? record) {
  if (record is! Map) return null;
  if (record['id'] case final Object id) return 'id:$id';
  if (record['lotCode'] case final Object lot) return 'lot:$lot:${record['date']}';
  return null;
}

bool _records(List l) => l.every((e) => _id(e) != null);

List<Object?> _mergeRecords(List base, List local, List remote, {required bool hasBase}) {
  final b = {for (final e in base) _id(e): e};
  final l = {for (final e in local) _id(e): e};
  final r = {for (final e in remote) _id(e): e};
  final out = <Object?>[];
  // L'ordre : celui du téléphone, puis les nouveaux du serveur.
  for (final id in {...l.keys, ...r.keys}) {
    final inL = l.containsKey(id), inR = r.containsKey(id), inB = hasBase && b.containsKey(id);
    if (inL && inR) {
      out.add(_merge(inB ? b[id] : null, l[id], r[id], hasBase: inB));
    } else if (inL) {
      // Absent du serveur : supprimé là-bas (si on le connaissait et qu'on
      // ne l'a pas changé), sinon ajouté ici.
      if (!(inB && _eq(b[id], l[id]))) out.add(l[id]);
    } else {
      if (!(inB && _eq(b[id], r[id]))) out.add(r[id]);
    }
  }
  return out;
}

bool _eq(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);
