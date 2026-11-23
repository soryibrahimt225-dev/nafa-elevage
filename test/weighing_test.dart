import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/weighing_store.dart';
import 'package:nafa_elevage/domain/feed.dart';
import 'package:nafa_elevage/domain/lots.dart';
import 'package:nafa_elevage/domain/production.dart';
import 'package:nafa_elevage/domain/weighing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final lot = AnimalLot(id: '1', code: 'CHA-26-014', production: ProductionType.chair, breed: 'Cobb 500',
      startDate: DateTime(2026, 10, 21), initialCount: 520)
    ..addMovement(Movement(date: DateTime(2026, 11, 1), type: MovementType.mortalite, count: 10));
  Weighing w(DateTime d, int g) => Weighing(id: '$d', lotCode: 'CHA-26-014', date: d, averageGrams: g);
  FeedMove f(DateTime d, int kg) =>
      FeedMove(id: '$d', itemId: 'a', date: d, type: FeedMoveType.distribution, grams: kg * 1000, lotCode: 'CHA-26-014');

  test('Indice de consommation entre deux pesées', () {
    final g = Growth(lot, [w(DateTime(2026, 11, 22), 1720), w(DateTime(2026, 10, 21), 40)], [
      f(DateTime(2026, 10, 21), 30), // le jour de la 1re pesée : exclu (avant le gain mesuré)
      f(DateTime(2026, 11, 5), 700),
      f(DateTime(2026, 11, 22), 800),
      f(DateTime(2026, 11, 23), 50), // après la dernière pesée : exclu
    ]);
    expect(g.days, 32);
    expect(g.gainPerSubject, 1680);
    expect(g.dailyGain, closeTo(52.5, 1e-9));
    expect(g.totalGain, 1680 * 510);
    expect(g.feedGrams, 1500000);
    expect(g.fcr, closeTo(1.75, 0.001));
    expect(formatFcr(g.fcr), '1,75');
    expect(g.flockWeight, 1720 * 510);
  });

  test('Une seule pesée ou sans aliment : pas d’indice', () {
    expect(Growth(lot, [w(DateTime(2026, 11, 22), 1720)], []).fcr, isNull);
    expect(Growth(lot, [w(DateTime(2026, 10, 21), 40), w(DateTime(2026, 11, 22), 1720)], []).fcr, isNull);
    expect(Growth(lot, [w(DateTime(2026, 10, 21), 900), w(DateTime(2026, 11, 22), 800)], [f(DateTime(2026, 11, 5), 10)]).fcr,
        isNull); // perte de poids : pas d'indice
  });

  test('Formats et contrôles', () {
    expect(formatWeight(850).replaceAll(' ', ' '), '850 g');
    expect(formatWeight(1720).replaceAll(' ', ' '), '1,72 kg');
    expect(() => w(DateTime(2026), 0), throwsArgumentError);
    expect(() => w(DateTime(2026), 25000), throwsArgumentError); // saisie en kg par erreur ?
  });

  test('Une pesée par lot et par jour', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await WeighingStore.load();
    await s.save(w(DateTime(2026, 11, 22), 1700));
    await s.save(Weighing(id: 'x', lotCode: 'CHA-26-014', date: DateTime(2026, 11, 22, 17), averageGrams: 1720));
    await s.save(w(DateTime(2026, 11, 1), 600));
    final again = await WeighingStore.load();
    expect(again.forLot('CHA-26-014').map((x) => x.averageGrams), [600, 1720]);
  });
}
