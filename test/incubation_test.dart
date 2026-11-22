import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/domain/incubation.dart';

/// Lots réels tirés de Gestion-couvoir-2026.xlsx (onglet Lots).
/// Convention : jour d'entrée = jour 0, éclosion = entrée + durée.
void main() {
  SpeciesProfile profile(String id) => defaultSpeciesProfiles.firstWhere((p) => p.id == id);

  group('Dates d’éclosion identiques au classeur', () {
    final cases = <(String, DateTime, int, DateTime)>[
      ('BUR-26-001', DateTime(2026, 5, 14), 21, DateTime(2026, 6, 4)),
      ('BUR-26-010 pintade', DateTime(2026, 7, 25), 28, DateTime(2026, 8, 22)),
      ('BUR-26-028', DateTime(2026, 11, 2), 21, DateTime(2026, 11, 23)),
      ('BUR-26-030', DateTime(2026, 11, 12), 21, DateTime(2026, 12, 3)),
      ('BUR-26-031', DateTime(2026, 11, 21), 21, DateTime(2026, 12, 12)),
    ];
    for (final (code, entry, days, expected) in cases) {
      test(code, () {
        final s = IncubationSchedule(entryDate: entry, incubationDays: days, descenteDay: days - 5);
        expect(s.hatchDate, expected);
      });
    }
  });

  test('Goliath : descente au jour 16, identique au classeur (éclosion − 5)', () {
    // BUR-26-029 : entrée 06/11/2026, descente 22/11/2026, éclosion 27/11/2026.
    final s = IncubationSchedule.forProfile(DateTime(2026, 11, 6), profile('goliath'));
    expect(s.descenteDate, DateTime(2026, 11, 22));
    expect(s.hatchDate, DateTime(2026, 11, 27));
  });

  test('Pintade : descente au jour 25 par défaut (le classeur donnait le jour 23)', () {
    final s = IncubationSchedule.forProfile(DateTime(2026, 7, 25), profile('pintade'));
    expect(s.descenteDate, DateTime(2026, 8, 19));
    expect(s.hatchDate, DateTime(2026, 8, 22));
  });

  test('Canard de Barbarie : 35 jours', () {
    final s = IncubationSchedule.forProfile(DateTime(2026, 11, 22), profile('barbarie'));
    expect(s.hatchDate, DateTime(2026, 12, 27));
    expect(s.descenteDate, DateTime(2026, 12, 23));
  });

  test('Mise en couveuse le 22/11 → éclosion le 13/12 (pas le 12/12)', () {
    final s = IncubationSchedule.forProfile(DateTime(2026, 11, 22), profile('goliath'));
    expect(s.hatchDate, DateTime(2026, 12, 13));
    expect(s.descenteDate, DateTime(2026, 12, 8));
  });

  test('Passage d’année et heure ignorée', () {
    final s = IncubationSchedule.forProfile(DateTime(2026, 12, 20, 18, 30), profile('poule'));
    expect(s.hatchDate, DateTime(2027, 1, 10));
  });

  group('Statuts (logique du classeur)', () {
    final s = IncubationSchedule.forProfile(DateTime(2026, 11, 6), profile('goliath'));
    test('en incubation', () => expect(s.statusAt(DateTime(2026, 11, 21)), IncubationStatus.enIncubation));
    test('œufs descendus', () => expect(s.statusAt(DateTime(2026, 11, 22)), IncubationStatus.descenteFaite));
    test('éclosion imminente la veille', () =>
        expect(s.statusAt(DateTime(2026, 11, 26)), IncubationStatus.eclosionImminente));
    test('à vérifier après 2 jours', () => expect(s.statusAt(DateTime(2026, 11, 30)), IncubationStatus.aVerifier));
    test('terminé si l’éclosion est saisie, même en avance', () =>
        expect(s.statusAt(DateTime(2026, 11, 25), hatchRecorded: true), IncubationStatus.termine));
    test('jour d’incubation', () => expect(s.dayAt(DateTime(2026, 11, 22)), 16));
  });

  group('Erreurs de saisie', () {
    test('durée nulle', () =>
        expect(() => IncubationSchedule(entryDate: DateTime(2026), incubationDays: 0, descenteDay: 0), throwsArgumentError));
    test('descente après l’éclosion', () =>
        expect(() => IncubationSchedule(entryDate: DateTime(2026), incubationDays: 21, descenteDay: 21), throwsArgumentError));
    test('plus d’éclos que d’œufs', () => expect(() => hatchRate(eggsSet: 10, hatched: 11), throwsArgumentError));
  });

  test('Taux d’éclosion global du classeur : 863 / 1 486 = 58,1 %', () {
    // 2 466 œufs mis, dont 1 486 sur les lots avec éclosion saisie (863 + 623).
    expect(hatchRate(eggsSet: 1486, hatched: 863)!, closeTo(0.5808, 0.0001));
    expect(hatchRate(eggsSet: 51), isNull);
  });
}
