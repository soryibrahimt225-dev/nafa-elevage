import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/domain/sync_merge.dart';

String j(Object o) => jsonEncode(o);
Object? d(String s) => jsonDecode(s);

void main() {
  final s1 = {'id': 's1', 'amount': 100};
  final s2 = {'id': 's2', 'amount': 200};
  final s3 = {'id': 's3', 'amount': 300};

  test('chaque téléphone a ajouté une vente : les deux sont gardées', () {
    final base = j({'sales': [s1], 'expenses': []});
    final local = j({'sales': [s1, s2], 'expenses': []});
    final remote = j({'sales': [s1, s3], 'expenses': []});
    expect(d(mergeValues(base, local, remote)), {'sales': [s1, s2, s3], 'expenses': []});
  });

  test('suppression d’un côté appliquée', () {
    final base = j([s1, s2]);
    expect(d(mergeValues(base, j([s1]), j([s1, s2]))), [s1]); // supprimé ici
    expect(d(mergeValues(base, j([s1, s2]), j([s2]))), [s2]); // supprimé là-bas
  });

  test('supprimé d’un côté mais modifié de l’autre : gardé', () {
    final base = j([s1]);
    final changed = {'id': 's1', 'amount': 150};
    expect(d(mergeValues(base, j([changed]), j(<Object>[]))), [changed]);
  });

  test('même enregistrement modifié des deux côtés : champs fusionnés', () {
    final base = j([{'id': 'l1', 'current': 100, 'notes': ''}]);
    final local = j([{'id': 'l1', 'current': 95, 'notes': ''}]);
    final remote = j([{'id': 'l1', 'current': 100, 'notes': 'vaccin fait'}]);
    expect(d(mergeValues(base, local, remote)), [{'id': 'l1', 'current': 95, 'notes': 'vaccin fait'}]);
  });

  test('œufs : clé lot + date', () {
    final base = j([]);
    final a = {'lotCode': 'PON-26-001', 'date': '2026-11-22', 'collected': 400};
    final b = {'lotCode': 'PON-26-001', 'date': '2026-11-23', 'collected': 410};
    expect((d(mergeValues(base, j([a]), j([b]))) as List).length, 2);
  });

  test('première synchronisation (pas de base) : union, valeurs du serveur', () {
    final local = j({'sales': [s1], 'farmName': 'Local'});
    final remote = j({'sales': [s2], 'farmName': 'Serveur'});
    expect(d(mergeValues(null, local, remote)), {'sales': [s1, s2], 'farmName': 'Serveur'});
  });

  test('texte simple : modification locale prioritaire', () {
    expect(mergeValues('chair', 'pondeuses', 'chair'), 'pondeuses');
    expect(mergeValues('chair', 'chair', 'couveuse'), 'couveuse');
    expect(mergeValues(null, 'chair', 'couveuse'), 'couveuse');
  });

  test('rien n’a changé localement : on prend le serveur', () {
    final base = j({'a': 1});
    expect(d(mergeValues(base, base, j({'a': 2}))), {'a': 2});
  });
}
