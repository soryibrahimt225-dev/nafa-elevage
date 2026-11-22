import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/domain/health.dart';
import 'package:nafa_elevage/domain/lots.dart';

IncubationLot lot(String code, DateTime entry, int eggs, {int? hatched, int? deaths, OwnerType o = OwnerType.producteur}) =>
    IncubationLot(id: code, code: code, ownerType: o, ownerName: o.label, speciesLabel: 'Goliath',
        entryDate: entry, eggsSet: eggs, incubationDays: 21, descenteDay: 16, hatched: hatched, chickDeaths: deaths);

void main() {
  group('Production mensuelle (lots de juin du classeur)', () {
    // Lots bureau dont l'éclosion prévue tombe en juin 2026.
    final juin = [
      lot('BUR-26-001', DateTime(2026, 5, 14), 42),
      lot('BUR-26-002', DateTime(2026, 5, 23), 24, hatched: 6, deaths: 1),
      lot('BUR-26-003', DateTime(2026, 5, 24), 24, hatched: 7, deaths: 1),
      lot('BUR-26-004', DateTime(2026, 5, 31), 79),
      lot('BUR-26-005', DateTime(2026, 6, 3), 60, hatched: 27, deaths: 5),
      lot('BUR-26-006', DateTime(2026, 6, 7), 58, hatched: 25),
      lot('BUR-26-008', DateTime(2026, 5, 31), 79, hatched: 18),
    ];
    final client = lot('CLI-26-001', DateTime(2026, 7, 14), 26, o: OwnerType.client);
    final aout = lot('BUR-26-011', DateTime(2026, 7, 25), 90, hatched: 53, deaths: 2);

    test('mêmes chiffres que l’onglet ProductionMensuelle', () {
      final rows = monthlyProduction([...juin, aout, client], owner: OwnerType.producteur);
      final j = rows.first;
      expect(j.month, DateTime(2026, 6));
      expect([j.lots, j.eggsSet, j.hatched, j.unhatched, j.deaths, j.alive], [7, 366, 83, 162, 7, 76]);
      expect(j.hatchRate, closeTo(0.3388, 1e-4)); // 33,9 % et non 83 / 366
      expect(j.mortalityRate, closeTo(0.0843, 1e-4));
    });
    test('mois vide inclus, clients filtrés', () {
      final rows = monthlyProduction([...juin, aout, client], owner: OwnerType.producteur);
      expect(rows.map((r) => r.month.month), [6, 7, 8]);
      expect(rows[1].lots, 0);
      expect(monthlyProduction([...juin, client], owner: OwnerType.client).single.lots, 1);
    });
    test('total', () {
      final t = totalOf(monthlyProduction([...juin, aout]));
      expect(t.lots, 8);
      expect(t.alive, 76 + 51);
    });
    test('aucun lot', () => expect(monthlyProduction([]), isEmpty));
  });

  group('Santé et vaccination', () {
    final today = DateTime(2026, 11, 22);
    HealthRecord r(DateTime planned, {DateTime? done}) => HealthRecord(
        id: 'h', lotCode: 'CHA-26-001', kind: HealthKind.vaccination, title: 'Vaccin prévu par le vétérinaire',
        plannedDate: planned, doneDate: done);
    test('statuts', () {
      expect(r(DateTime(2026, 11, 25)).statusAt(today), HealthStatus.aVenir);
      expect(r(DateTime(2026, 11, 22)).statusAt(today), HealthStatus.aujourdhui);
      expect(r(DateTime(2026, 11, 19)).statusAt(today), HealthStatus.enRetard);
      expect(r(DateTime(2026, 11, 19)).lateDays(today), 3);
      expect(r(DateTime(2026, 11, 19), done: DateTime(2026, 11, 20)).statusAt(today), HealthStatus.realise);
    });
    test('marquer réalisé', () {
      final x = r(DateTime(2026, 11, 19))..markDone(DateTime(2026, 11, 21, 15), product: 'Produit X');
      expect(x.doneDate, DateTime(2026, 11, 21));
      expect(x.product, 'Produit X');
      expect(x.lateDays(today), 0);
    });
    test('nom obligatoire', () {
      expect(() => HealthRecord(id: 'h', lotCode: 'L', kind: HealthKind.autre, title: ' ', plannedDate: today),
          throwsArgumentError);
    });
    test('aller-retour JSON', () {
      final x = HealthRecord.fromJson(r(DateTime(2026, 11, 19), done: DateTime(2026, 11, 20)).toJson());
      expect(x.doneDate, DateTime(2026, 11, 20));
    });
  });
}
