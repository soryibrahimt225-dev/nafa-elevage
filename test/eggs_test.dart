import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/egg_store.dart';
import 'package:nafa_elevage/domain/eggs.dart';
import 'package:nafa_elevage/domain/lots.dart';
import 'package:nafa_elevage/domain/production.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Œufs de table et contrôles', () {
    final r = EggRecord(lotCode: 'PON-26-001', date: DateTime(2026, 11, 23, 8), collected: 410, broken: 6, fertile: 30);
    expect(r.table, 374);
    expect(r.date, DateTime(2026, 11, 23));
    expect(() => EggRecord(lotCode: 'X', date: DateTime(2026), collected: 10, broken: 6, fertile: 5), throwsArgumentError);
    expect(() => EggRecord(lotCode: 'X', date: DateTime(2026), collected: -1), throwsArgumentError);
  });

  test('Taux de ponte', () {
    expect(layingRate(410, 476), closeTo(0.8613, 1e-4));
    expect(layingRate(10, 0), isNull);
  });

  test('Effectif à une date (pour le taux du jour)', () {
    final lot = AnimalLot(id: '1', code: 'PON-26-001', production: ProductionType.pondeuses, breed: 'ISA Brown',
        startDate: DateTime(2026, 6, 1), initialCount: 500)
      ..addMovement(Movement(date: DateTime(2026, 11, 10), type: MovementType.mortalite, count: 4))
      ..addMovement(Movement(date: DateTime(2026, 11, 20), type: MovementType.reforme, count: 20));
    expect(lot.countAt(DateTime(2026, 11, 9)), 500);
    expect(lot.countAt(DateTime(2026, 11, 10)), 496);
    expect(lot.countAt(DateTime(2026, 11, 23)), 476);
    expect(lot.countOf(MovementType.reforme), 20);
  });

  test('Une saisie par lot et par jour, synthèse sur la période', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await EggStore.load();
    await store.save(EggRecord(lotCode: 'A', date: DateTime(2026, 11, 22), collected: 400, broken: 4));
    await store.save(EggRecord(lotCode: 'A', date: DateTime(2026, 11, 23), collected: 300));
    await store.save(EggRecord(lotCode: 'A', date: DateTime(2026, 11, 23), collected: 410, broken: 6)); // correction
    await store.save(EggRecord(lotCode: 'B', date: DateTime(2026, 11, 23), collected: 50));
    final again = await EggStore.load();
    final week = EggSummary(again.between({'A'}, DateTime(2026, 11, 17), DateTime(2026, 11, 23)));
    expect(week.collected, 810);
    expect(week.broken, 10);
    expect(week.days, hasLength(2));
    expect(again.find('A', DateTime(2026, 11, 23, 15))!.collected, 410);
  });
}
