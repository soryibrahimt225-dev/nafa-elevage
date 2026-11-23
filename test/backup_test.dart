import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/app_data.dart';
import 'package:nafa_elevage/data/backup_service.dart';
import 'package:nafa_elevage/domain/farm.dart';
import 'package:nafa_elevage/domain/finance.dart';
import 'package:nafa_elevage/domain/lots.dart';
import 'package:nafa_elevage/domain/production.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List bytesOf(Object j) => Uint8List.fromList(utf8.encode(jsonEncode(j)));

Future<AppData> farm() async {
  SharedPreferences.setMockInitialValues({});
  final d = await AppData.load();
  await d.settings.choose(ProductionType.ameliorees, {OptionalFeature.couvaisonConversion});
  await d.settings.setFarm(FarmProfile(name: 'Ferme de Kati', location: 'Kati', users: [FarmUser('Sory', UserRole.proprietaire)]));
  await d.lots.addAnimalLot(AnimalLot(id: '1', code: 'AME-26-001', production: ProductionType.ameliorees,
      breed: 'Goliath', startDate: DateTime(2026, 10, 1), initialCount: 120, objectives: {LotObjective.ponte}));
  await d.finance.addSale(Sale(id: 's', date: DateTime(2026, 11, 20), category: SaleCategory.sujets, quantity: 10,
      unitPrice: 6000, amountPaid: 60000, production: ProductionType.ameliorees));
  await d.config.setPrice(SaleCategory.sujets, 6000);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('nafa.reminders.v1', '{"AME-26-001":{"channel":"agenda","calendar":["x"],"notifications":[]}}');
  return d;
}

void main() {
  final now = DateTime(2026, 11, 23, 10);

  test('Sauvegarde puis restauration sur un « nouveau téléphone »', () async {
    await farm();
    final service = BackupService(await SharedPreferences.getInstance(), clock: () => now);
    final file = await service.export();
    expect(service.lastBackupAt, now);
    expect(service.fileName('Ferme de Kati'), 'nafa-sauvegarde-ferme-de-kati-2026-11-23.json');
    final content = utf8.decode(file);
    expect(content, isNot(contains('nafa.reminders.v1'))); // rappels propres au téléphone

    // Nouveau téléphone, vide
    SharedPreferences.setMockInitialValues({});
    final empty = BackupService(await SharedPreferences.getInstance(), clock: () => now);
    final info = empty.inspect(file);
    expect(info.summary, contains('Ferme de Kati'));
    expect(info.summary, contains('1 lot(s) de sujets'));
    expect(info.summary, contains('1 vente(s)'));
    await empty.restore(file);

    final d = await AppData.load();
    expect(d.settings.production, ProductionType.ameliorees);
    expect(d.settings.options, {OptionalFeature.couvaisonConversion}); // liste relue comme liste
    expect(d.settings.farm.displayName, 'Ferme de Kati');
    expect(d.settings.farm.users.single.name, 'Sory');
    expect(d.lots.animalLots(ProductionType.ameliorees).single.objectives, {LotObjective.ponte});
    expect(d.finance.accounting().global.sales, 60000);
    expect(d.config.priceFor(SaleCategory.sujets), 6000);
  });

  test('La restauration remplace tout et peut être annulée', () async {
    await farm();
    final prefs = await SharedPreferences.getInstance();
    final service = BackupService(prefs, clock: () => now);
    final file = await service.export();
    // Nouvelles données après la sauvegarde
    final d = await AppData.load();
    await d.lots.addAnimalLot(AnimalLot(id: '2', code: 'AME-26-002', production: ProductionType.ameliorees,
        breed: 'Kuroiler', startDate: DateTime(2026, 11, 1), initialCount: 50));
    await service.restore(file);
    expect((await AppData.load()).lots.animalLots(ProductionType.ameliorees).map((l) => l.code), ['AME-26-001']);
    expect(service.canUndoRestore, isTrue);
    await service.undoRestore();
    expect((await AppData.load()).lots.animalLots(ProductionType.ameliorees).length, 2);
    expect(service.canUndoRestore, isFalse);
  });

  group('Fichiers refusés', () {
    late BackupService service;
    setUp(() async {
      SharedPreferences.setMockInitialValues({'nafa.production': 'chair'});
      service = BackupService(await SharedPreferences.getInstance(), clock: () => now);
    });
    test('pas du JSON', () {
      expect(() => service.inspect(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });
    test('autre application', () {
      expect(() => service.inspect(bytesOf({'app': 'autre', 'format': 1, 'data': {}})), throwsFormatException);
    });
    test('version plus récente', () {
      expect(
          () => service.inspect(bytesOf({'app': 'nafa-elevage', 'format': 99, 'data': {}})),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('version plus récente'))));
    });
    test('fichier abîmé : rien n’est changé', () async {
      final bad = bytesOf({
        'app': 'nafa-elevage',
        'format': 1,
        'createdAt': now.toIso8601String(),
        'data': {'nafa.production': 'pondeuses', 'nafa.lots.v1': '{"animal": "abîmé"}'},
      });
      await expectLater(service.restore(bad), throwsFormatException);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nafa.production'), 'chair');
      expect(prefs.getString('nafa.lots.v1'), isNull);
      expect(service.canUndoRestore, isFalse);
    });
  });

  test('Recommencer à zéro : tout est effacé', () async {
    await farm();
    final prefs = await SharedPreferences.getInstance();
    await BackupService(prefs).resetAll();
    final d = await AppData.load();
    expect(d.settings.isConfigured, isFalse);
    expect(d.lots.animalLots(ProductionType.ameliorees), isEmpty);
    expect(d.finance.sales, isEmpty);
    expect(prefs.getKeys().where((k) => k.startsWith('nafa.')), isEmpty);
  });
}
