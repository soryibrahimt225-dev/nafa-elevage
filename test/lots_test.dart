import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/excel_import.dart';
import 'package:nafa_elevage/data/lot_store.dart';
import 'package:nafa_elevage/domain/incubation.dart';
import 'package:nafa_elevage/domain/lots.dart';
import 'package:nafa_elevage/domain/production.dart';
import 'package:shared_preferences/shared_preferences.dart';

AnimalLot chair({int count = 500, DateTime? start}) => AnimalLot(
      id: 'a1',
      code: 'CHA-26-001',
      production: ProductionType.chair,
      breed: 'Cobb 500',
      startDate: start ?? DateTime(2026, 11, 1),
      initialCount: count,
    );

IncubationLot oeufs({String code = 'BUR-26-001', int eggs = 100, DateTime? entry, int? hatched, int? deaths}) =>
    IncubationLot(
      id: code,
      code: code,
      ownerType: OwnerType.producteur,
      ownerName: 'Producteur',
      speciesLabel: 'Goliath',
      entryDate: entry ?? DateTime(2026, 11, 6),
      eggsSet: eggs,
      incubationDays: 21,
      descenteDay: 16,
      hatched: hatched,
      chickDeaths: deaths,
    );

void main() {
  group('Codes de lots', () {
    test('premier code de l’année', () => expect(nextLotCode('CHA', DateTime(2026, 3, 1), []), 'CHA-26-001'));
    test('suite après le plus grand numéro, par préfixe et par année', () {
      final codes = ['BUR-26-031', 'BUR-26-007', 'CLI-26-008', 'BUR-25-090'];
      expect(nextLotCode('BUR', DateTime(2026, 12, 1), codes), 'BUR-26-032');
      expect(nextLotCode('CLI', DateTime(2026, 12, 1), codes), 'CLI-26-009');
      expect(nextLotCode('BUR', DateTime(2027, 1, 2), codes), 'BUR-27-001');
    });
  });

  group('Lot de sujets', () {
    test('effectif actuel calculé à partir des sorties', () {
      final l = chair();
      l.addMovement(Movement(date: DateTime(2026, 11, 3), type: MovementType.mortalite, count: 12));
      l.addMovement(Movement(date: DateTime(2026, 11, 20), type: MovementType.vente, count: 100));
      expect(l.current, 388);
      expect(l.dead, 12);
      expect(l.mortalityRate, closeTo(0.024, 1e-9));
      expect(l.ageAt(DateTime(2026, 11, 22)), 21);
      expect(l.status, LotStatus.enCours);
    });
    test('plus de sorties que de sujets refusé', () {
      final l = chair(count: 10);
      expect(() => l.addMovement(Movement(date: DateTime(2026, 11, 2), type: MovementType.mortalite, count: 11)),
          throwsArgumentError);
    });
    test('sortie avant la création du lot refusée', () {
      expect(() => chair().addMovement(Movement(date: DateTime(2026, 10, 31), type: MovementType.mortalite, count: 1)),
          throwsArgumentError);
    });
    test('lot vide → terminé', () {
      final l = chair(count: 5);
      l.addMovement(Movement(date: DateTime(2026, 11, 2), type: MovementType.vente, count: 5));
      expect(l.status, LotStatus.termine);
    });
    test('saisies invalides', () {
      expect(() => chair(count: 0), throwsArgumentError);
      expect(
          () => AnimalLot(id: 'x', code: 'x', production: ProductionType.couveuse, breed: 'Goliath',
              startDate: DateTime(2026), initialCount: 1),
          throwsArgumentError);
    });
    test('aller-retour JSON', () {
      final l = chair()..objective = LotObjective.ponte;
      l.addMovement(Movement(date: DateTime(2026, 11, 3), type: MovementType.mortalite, count: 2, note: 'chaleur'));
      final copy = AnimalLot.fromJson(l.toJson());
      expect(copy.current, 498);
      expect(copy.objective, LotObjective.ponte);
      expect(copy.movements.single.note, 'chaleur');
      expect(copy.startDate, DateTime(2026, 11, 1));
    });
  });

  group('Lot d’œufs', () {
    test('BUR-26-024 du classeur : 138 œufs, 74 éclos, 2 morts', () {
      final l = oeufs(eggs: 138, hatched: 74, deaths: 2, entry: DateTime(2026, 10, 13));
      expect(l.unhatched, 64);
      expect(l.alive, 72);
      expect(l.hatchRate, closeTo(0.5362, 1e-4));
      expect(l.schedule.hatchDate, DateTime(2026, 11, 3));
      expect(l.statusAt(DateTime(2026, 11, 22)), IncubationStatus.termine);
    });
    test('mortalité = éclos signalée (BUR-26-020)', () {
      expect(oeufs(hatched: 36, deaths: 36).suspiciousMortality, isTrue);
      expect(oeufs(hatched: 36, deaths: 3).suspiciousMortality, isFalse);
    });
    test('contrôles de saisie', () {
      expect(() => oeufs(eggs: 10, hatched: 11), throwsArgumentError);
      expect(() => oeufs(hatched: 5, deaths: 6), throwsArgumentError);
      expect(() => oeufs(deaths: 1), throwsArgumentError);
      final l = oeufs(hatched: 50);
      expect(() => l.recordHatch(hatched: 50, chickDeaths: 60), throwsArgumentError);
      expect(l.hatched, 50, reason: 'une saisie refusée ne modifie rien');
    });
    test('aller-retour JSON', () {
      final copy = IncubationLot.fromJson(oeufs(hatched: 70, deaths: 1).toJson());
      expect(copy.alive, 69);
      expect(copy.entryDate, DateTime(2026, 11, 6));
    });
  });

  group('Calendrier et synthèse (situation du classeur au 22/11/2026)', () {
    final lots = [
      oeufs(code: 'BUR-26-028', eggs: 51, entry: DateTime(2026, 11, 2), hatched: 25),
      oeufs(code: 'BUR-26-029', eggs: 128, entry: DateTime(2026, 11, 6)),
      oeufs(code: 'BUR-26-030', eggs: 97, entry: DateTime(2026, 11, 12)),
      oeufs(code: 'BUR-26-026', eggs: 75, entry: DateTime(2026, 10, 21)),
    ];
    final today = DateTime(2026, 11, 22);
    test('échéances des 10 prochains jours, sans le lot déjà éclos', () {
      final e = upcomingEvents(lots, today);
      expect([for (final x in e) '${x.lot.code} ${x.label} ${x.date.day}/${x.date.month}'], [
        'BUR-26-029 Descente des œufs 22/11',
        'BUR-26-029 Éclosion prévue 27/11',
        'BUR-26-030 Descente des œufs 28/11',
      ]); // l'éclosion de BUR-26-030 (3/12) est à 11 jours : hors fenêtre, comme dans le classeur
      expect(upcomingEvents(lots, today, days: 11).last.label, 'Éclosion prévue');
    });
    test('synthèse : taux sur les seuls lots avec résultat', () {
      final s = IncubationSummary(lots, today);
      expect(s.eggsSet, 351);
      expect(s.hatchRate, closeTo(25 / 51, 1e-9));
      expect(s.running, 2);
      expect(s.eggsRunning, 225);
      expect(s.missingResult, 1); // BUR-26-026 : éclosion passée non saisie
    });
  });

  group('Import du classeur', () {
    List<Object?> row(String? code, DateTime? d, String type, String owner, int? days, int? eggs,
            {int? hatched, int? deaths, String obs = ''}) =>
        [code, d, type, owner, days, eggs, null, null, null, hatched, null, null, deaths, null, null, null, null, null, obs];

    test('lignes valides, totaux et lignes ignorées', () {
      final r = importLotRows([
        row('BUR-26-001', DateTime(2026, 5, 14), 'Bureau', 'Bureau', 21, 42),
        row('BUR-26-002', DateTime(2026, 5, 23), 'Bureau', 'Bureau', 21, 24, hatched: 6, deaths: 1),
        row(null, DateTime(2026, 7, 14), 'Client', 'Client A', 21, 26),
        row('BUR-26-010', DateTime(2026, 7, 25), 'Bureau', 'Bureau', 28, 75),
        row(null, DateTime(2026, 8, 1), 'Voisin', 'X', 21, 10),
        row('BUR-26-003', DateTime(2026, 5, 24), 'Bureau', 'Bureau', 21, 24, hatched: 30),
        [],
        ['TOTAL / MOYENNE', null, null, null, null, 191],
      ]);
      expect(r.lots.map((l) => l.code), ['BUR-26-001', 'BUR-26-002', 'CLI-26-001', 'BUR-26-010']);
      expect(r.lots[1].alive, 5);
      expect(r.lots[2].ownerType, OwnerType.client);
      expect(r.lots[3].speciesLabel, 'Pintade');
      expect(r.lots[3].schedule.hatchDate, DateTime(2026, 8, 22));
      expect(r.warnings, hasLength(2)); // type inconnu, éclos > œufs
    });
    test('pas de doublon avec les lots existants', () {
      final r = importLotRows([row('BUR-26-001', DateTime(2026, 5, 14), 'Bureau', 'Bureau', 21, 42)],
          existingCodes: ['BUR-26-001']);
      expect(r.lots, isEmpty);
      expect(r.warnings.single, contains('existe déjà'));
    });
    test('additions saisies dans les cellules', () {
      expect(evalSimpleSum('88+9'), 97);
      expect(evalSimpleSum('=87 + 20 - 1'), 106);
      expect(evalSimpleSum('SUM(A1:A3)'), isNull);
    });
  });

  test('Enregistrement : les lots survivent au redémarrage, sans mélange entre productions', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LotStore.load();
    await store.addAnimalLot(chair());
    await store.addAnimalLot(AnimalLot(
        id: 'p1', code: 'PON-26-001', production: ProductionType.pondeuses, breed: 'ISA Brown',
        startDate: DateTime(2026, 9, 1), initialCount: 300));
    await store.addIncubationLot(oeufs());
    expect(() => store.addIncubationLot(oeufs()), throwsArgumentError);

    final reloaded = await LotStore.load();
    expect(reloaded.animalLots(ProductionType.chair).map((l) => l.code), ['CHA-26-001']);
    expect(reloaded.animalLots(ProductionType.pondeuses).map((l) => l.code), ['PON-26-001']);
    expect(reloaded.animalLots(ProductionType.ameliorees), isEmpty);
    expect(reloaded.incubationLots.single.code, 'BUR-26-001');
    expect(reloaded.nextIncubationCode(OwnerType.producteur, DateTime(2026, 12, 1)), 'BUR-26-002');
  });
}
