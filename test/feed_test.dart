import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/feed_store.dart';
import 'package:nafa_elevage/domain/feed.dart';
import 'package:shared_preferences/shared_preferences.dart';

FeedMove move(String id, FeedMoveType t, int kg, {int cost = 0, String? lot, String item = 'pon'}) =>
    FeedMove(id: id, itemId: item, date: DateTime(2026, 11, 11), type: t, grams: kg * 1000, cost: cost, lotCode: lot);

void main() {
  final pondeuse = FeedItem(id: 'pon', name: 'Aliment pondeuse', stage: FeedStage.pondeuse, alertKg: 25);

  group('Formats et saisie', () {
    test('kg', () {
      expect(formatKg(12500).replaceAll(' ', ' '), '12,5 kg');
      expect(formatKg(3000000).replaceAll(' ', ' '), '3 000 kg');
      expect(formatKg(950).replaceAll(' ', ' '), '1 kg');
      expect(formatKg(0).replaceAll(' ', ' '), '0 kg');
    });
    test('saisie', () {
      expect(parseKg('12,5'), 12500);
      expect(parseKg('12.5'), 12500);
      expect(parseKg('abc'), isNull);
    });
    test('ration : 476 sujets × 115 g = 54,74 kg', () => expect(rationGrams(476, 115), 54740));
  });

  group('Stock et coût', () {
    // Classeur : aliment pondeuse 28 500 FCFA le sac (supposé de 50 kg).
    final moves = [
      move('1', FeedMoveType.achat, 50, cost: 28500),
      move('2', FeedMoveType.achat, 100, cost: 60000),
      move('3', FeedMoveType.distribution, 60, lot: 'PON-26-001'),
      move('4', FeedMoveType.distribution, 40, lot: 'PON-26-002'),
      move('5', FeedMoveType.perte, 5),
    ];
    final s = FeedStock(pondeuse, moves);
    test('reste, coût moyen, valeur', () {
      expect(s.remainingGrams, 45000);
      expect(s.costPerKg, closeTo(590, 1e-9)); // 88 500 / 150 kg
      expect(s.value, 26550);
      expect(s.low, isFalse);
    });
    test('consommation et coût par lot', () {
      final f = LotFeed('PON-26-001', moves, {'pon': s});
      expect(f.grams, 60000);
      expect(f.costFcfa, 35400);
      expect(f.gramsPerSubjectPerDay(subjects: 500, days: 1), 120);
      expect(f.firstDate, DateTime(2026, 11, 11));
    });
    test('alerte de stock bas', () {
      expect(FeedStock(pondeuse, [move('1', FeedMoveType.achat, 20, cost: 10000)]).low, isTrue);
    });
    test('distribution sans achat : coût inconnu signalé', () {
      final f = LotFeed('L', [move('9', FeedMoveType.distribution, 10, lot: 'L', item: 'x')], {});
      expect(f.unpricedGrams, 10000);
      expect(f.costFcfa, 0);
    });
  });

  group('Contrôles', () {
    test('saisies invalides', () {
      expect(() => FeedItem(id: 'a', name: ' ', stage: FeedStage.autre), throwsArgumentError);
      expect(() => FeedItem(id: 'a', name: 'A', stage: FeedStage.autre, kgPerBag: 0), throwsArgumentError);
      expect(() => move('x', FeedMoveType.distribution, 5), throwsArgumentError); // sans lot
      expect(() => move('x', FeedMoveType.achat, 0), throwsArgumentError);
    });
    test('pas de distribution au-delà du stock, achat distribué non supprimable', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await FeedStore.load();
      await store.saveItem(pondeuse);
      expect(() => store.saveItem(FeedItem(id: 'b', name: 'aliment PONDEUSE', stage: FeedStage.pondeuse)),
          throwsArgumentError);
      await store.addMove(move('1', FeedMoveType.achat, 50, cost: 28500));
      expect(() => store.addMove(move('2', FeedMoveType.distribution, 51, lot: 'L')), throwsArgumentError);
      await store.addMove(move('3', FeedMoveType.distribution, 30, lot: 'L'));
      expect(() => store.deleteMove('1'), throwsArgumentError);
      final again = await FeedStore.load();
      expect(again.stockOf('pon').remainingGrams, 20000);
      expect(again.forLot('L').costFcfa, 17100);
    });
  });
}
