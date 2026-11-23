import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/config_store.dart';
import 'package:nafa_elevage/domain/config.dart';
import 'package:nafa_elevage/domain/finance.dart';
import 'package:nafa_elevage/domain/incubation.dart';
import 'package:nafa_elevage/domain/production.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Ajout de mois', () {
    test('cas simples', () {
      expect(addMonths(DateTime(2026, 11, 22), 4), DateTime(2027, 3, 22));
      expect(addMonths(DateTime(2026, 11, 22), 24), DateTime(2028, 11, 22));
    });
    test('fin de mois', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2027, 12, 31), 2), DateTime(2028, 2, 29));
    });
  });

  test('Cycle par défaut d’une race améliorée (4, 6, 12, 24 mois)', () {
    final steps = const ImprovedCycle().milestones(DateTime(2026, 10, 1));
    expect(steps.map((s) => s.$2), [
      DateTime(2027, 2, 1),
      DateTime(2027, 4, 1),
      DateTime(2027, 10, 1),
      DateTime(2028, 10, 1),
    ]);
  });

  test('Cycle incohérent refusé', () {
    expect(() => ImprovedCycle.validate(6, 4, 12, 24), throwsArgumentError);
    expect(() => ImprovedCycle.validate(0, 4, 12, 24), throwsArgumentError);
    ImprovedCycle.validate(4, 4, 12, 24);
  });

  test('Paramètres enregistrés et rechargés', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await ConfigStore.load();
    expect(c.species.map((s) => s.id), contains('barbarie'));
    await c.setSpecies(const SpeciesProfile(id: 'pintade', label: 'Pintade', incubationDays: 27, descenteDay: 24));
    await c.setSpecies(const SpeciesProfile(id: 'caille', label: 'Caille', incubationDays: 17, descenteDay: 14));
    await c.addBreed(ProductionType.ameliorees, 'Brahma');
    await c.removeBreed(ProductionType.chair, 'Ross 308');
    await c.setPrice(SaleCategory.poussins, 700);
    await c.setCycle('Goliath', const ImprovedCycle(selectionMonths: 3, layingStartMonths: 5));

    final again = await ConfigStore.load();
    expect(again.species.firstWhere((s) => s.id == 'pintade').descenteDay, 24);
    expect(again.species.last.label, 'Caille');
    expect(again.breedsFor(ProductionType.ameliorees), contains('Brahma'));
    expect(again.breedsFor(ProductionType.chair), isNot(contains('Ross 308')));
    expect(again.priceFor(SaleCategory.poussins), 700);
    expect(again.cycleFor('Goliath').selectionMonths, 3);
    expect(again.cycleFor('Kuroiler').selectionMonths, 4); // valeur par défaut
  });

  test('Saisies invalides refusées', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await ConfigStore.load();
    expect(() => c.setSpecies(const SpeciesProfile(id: 'x', label: 'X', incubationDays: 21, descenteDay: 21)),
        throwsArgumentError);
    expect(() => c.setSpecies(const SpeciesProfile(id: 'y', label: 'pintade', incubationDays: 28, descenteDay: 25)),
        throwsArgumentError); // doublon
    expect(() => c.addBreed(ProductionType.chair, 'cobb 500'), throwsArgumentError);
    expect(() => c.setPrice(SaleCategory.poussins, -1), throwsArgumentError);
  });
}
