import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/app_data.dart';
import 'package:nafa_elevage/data/sync_api.dart';
import 'package:nafa_elevage/domain/finance.dart';
import 'package:nafa_elevage/domain/lots.dart';
import 'package:nafa_elevage/domain/production.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test de bout en bout avec le vrai serveur et PostgreSQL :
/// SYNC_TEST_URL=http://localhost:8090 (base vide).
/// Deux « téléphones » sont simulés en changeant le stockage local.
void main() {
  final url = Platform.environment['SYNC_TEST_URL'];
  if (url == null) {
    test('Serveur non configuré', () {}, skip: 'SYNC_TEST_URL absent');
    return;
  }

  final phones = <String, Map<String, Object>>{};
  Future<void> use(String phone) async {
    SharedPreferences.setMockInitialValues(phones[phone] ?? {});
  }

  Future<void> keep(String phone) async {
    final p = await SharedPreferences.getInstance();
    phones[phone] = {for (final k in p.getKeys()) k: p.get(k)!};
  }

  test('Propriétaire et comptable synchronisent la même ferme', () async {
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000000;
    final ownerPhone = '7${stamp.toString().padLeft(8, '0')}';
    final accPhone = '6${stamp.toString().padLeft(8, '0')}';

    // ── Téléphone du propriétaire : données, compte, création de la ferme
    await use('A');
    var d = await AppData.load();
    await d.settings.choose(ProductionType.chair, {});
    await d.lots.addAnimalLot(AnimalLot(id: 'l1', code: 'CHA-26-001', production: ProductionType.chair,
        breed: 'Cobb 500', startDate: DateTime(2026, 11, 1), initialCount: 500));
    await d.sync.setServer(url);
    expect(await d.sync.register(ownerPhone, 'Sory', 'secret123'), isEmpty);
    final first = await d.sync.createFarm('Ferme de Kati', 'Kati');
    expect(first.sent, greaterThanOrEqualTo(3)); // production, options, lots…
    expect(d.sync.role, 'proprietaire');
    await keep('A');

    // ── Téléphone de la comptable : compte, puis ajout par le propriétaire
    await use('B');
    d = await AppData.load();
    await d.sync.setServer(url);
    await d.sync.register(accPhone, 'Awa', 'secret123');
    await keep('B');

    await use('A');
    d = await AppData.load();
    await d.sync.addMember(accPhone, 'comptable');
    expect((await d.sync.members()).length, 2);
    await keep('A');

    // ── La comptable rejoint la ferme : elle reçoit le lot du propriétaire
    await use('B');
    d = await AppData.load();
    final farms = await d.sync.farms();
    expect(farms.single.role, 'comptable');
    final joined = await d.sync.joinFarm(farms.single);
    expect(joined.received, greaterThan(0));
    d = await AppData.load();
    expect(d.settings.production, ProductionType.chair);
    expect(d.lots.animalLots(ProductionType.chair).single.code, 'CHA-26-001');
    // Elle enregistre une vente, et (sans en avoir le droit) un nouveau lot
    await d.finance.addSale(Sale(id: 's-b', date: DateTime(2026, 11, 20), category: SaleCategory.sujets, quantity: 50,
        unitPrice: 3500, amountPaid: 175000, production: ProductionType.chair));
    await d.lots.addAnimalLot(AnimalLot(id: 'l2', code: 'CHA-26-002', production: ProductionType.chair,
        breed: 'Ross 308', startDate: DateTime(2026, 11, 20), initialCount: 100));
    final r = await d.sync.sync();
    expect(r.sent, 1); // la vente
    expect(r.refused, ['nafa.lots.v1']); // le lot : refusé par le serveur
    d = await AppData.load();
    expect(d.lots.animalLots(ProductionType.chair).map((l) => l.code), ['CHA-26-001']); // annulé localement
    await keep('B');

    // ── Pendant ce temps, le propriétaire (hors ligne) a aussi enregistré une vente
    await use('A');
    d = await AppData.load();
    await d.finance.addSale(Sale(id: 's-a', date: DateTime(2026, 11, 21), category: SaleCategory.sujets, quantity: 20,
        unitPrice: 3600, amountPaid: 72000, production: ProductionType.chair));
    final r2 = await d.sync.sync();
    expect(r2.merged, 1); // conflit sur les ventes, fusionné
    d = await AppData.load();
    expect(d.finance.sales.map((s) => s.id).toSet(), {'s-a', 's-b'}); // les deux ventes
    expect(d.finance.accounting().global.sales, 247000);
    await keep('A');

    // ── La comptable reçoit la vente du propriétaire
    await use('B');
    d = await AppData.load();
    await d.sync.sync();
    d = await AppData.load();
    expect(d.finance.sales.length, 2);
    expect(d.sync.pendingKeys, isEmpty);

    // Mauvais mot de passe : message clair
    await expectLater(d.sync.login(ownerPhone, 'faux'),
        throwsA(isA<SyncException>().having((e) => e.message, 'message', contains('incorrect'))));
  });
}
