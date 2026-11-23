import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/lot_store.dart';
import 'package:nafa_elevage/domain/lots.dart';
import 'package:nafa_elevage/domain/production.dart';
import 'package:shared_preferences/shared_preferences.dart';

IncubationLot hatch(String code, int eggs, int hatched, int deaths) => IncubationLot(
    id: code, code: code, ownerType: OwnerType.producteur, ownerName: 'Producteur', speciesLabel: 'Goliath',
    entryDate: DateTime(2026, 10, 13), eggsSet: eggs, incubationDays: 21, descenteDay: 16,
    hatched: hatched, chickDeaths: deaths);

AnimalLot band(String code, Map<String, int> origins, {DateTime? start}) => AnimalLot(
    id: code, code: code, production: ProductionType.couveuse, breed: 'Goliath',
    startDate: start ?? DateTime(2026, 11, 3), initialCount: origins.values.fold(0, (s, n) => s + n), origins: origins);

void main() {
  // Classeur : bande EL-26-002 = poussins des éclosions BUR-26-024 et BUR-26-025.
  final l24 = hatch('BUR-26-024', 138, 74, 2); // 72 vivants
  final l25 = hatch('BUR-26-025', 107, 75, 0); // 75 vivants

  test('Répartition des poussins : gardés, vendus, disponibles', () {
    final bands = [band('EL-26-002', {'BUR-26-024': 12, 'BUR-26-025': 10})];
    final b24 = ChickBalance(lot: l24, bands: bands, sold: 50);
    expect(b24.alive, 72);
    expect(b24.kept, 12);
    expect(b24.available, 10);
    expect(ChickBalance(lot: l25, bands: bands, sold: 0).available, 65);
  });

  test('Une bande doit venir d’une éclosion et son effectif = total repris', () {
    expect(() => AnimalLot(id: 'x', code: 'EL-26-001', production: ProductionType.couveuse, breed: 'Goliath',
        startDate: DateTime(2026, 11, 1), initialCount: 10), throwsArgumentError);
    expect(() => AnimalLot(id: 'x', code: 'EL-26-001', production: ProductionType.couveuse, breed: 'Goliath',
        startDate: DateTime(2026, 11, 1), initialCount: 10, origins: {'BUR-26-024': 9}), throwsArgumentError);
    expect(() => band('EL', {'BUR-26-024': 0}), throwsArgumentError);
  });

  test('Code EL, âge, mortalité et enregistrement', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LotStore.load();
    expect(store.nextAnimalCode(ProductionType.couveuse, DateTime(2026, 11, 3)), 'EL-26-001');
    final b = band('EL-26-001', {'BUR-26-024': 22})
      ..addMovement(Movement(date: DateTime(2026, 11, 10), type: MovementType.mortalite, count: 2));
    await store.addAnimalLot(b);
    final again = await LotStore.load();
    final x = again.animalLots(ProductionType.couveuse).single;
    expect(x.origins, {'BUR-26-024': 22});
    expect(x.current, 20);
    expect(x.ageAt(DateTime(2026, 11, 22)), 19);
    expect(x.isChickBand, isTrue);
    expect(again.animalLots(ProductionType.ameliorees), isEmpty);
  });
}
