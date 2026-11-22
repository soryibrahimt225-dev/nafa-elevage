import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/domain/format.dart';
import 'package:nafa_elevage/domain/production.dart';

String plain(String s) => s.replaceAll(' ', ' ');

void main() {
  group('Montants complets, jamais abrégés', () {
    test('chiffres du classeur', () {
      expect(plain(formatFcfa(588256)), '588 256 FCFA');
      expect(plain(formatFcfa(570476)), '570 476 FCFA');
      expect(plain(formatFcfa(89500)), '89 500 FCFA');
      expect(plain(formatFcfa(498756)), '498 756 FCFA');
      expect(plain(formatFcfa(17780)), '17 780 FCFA');
    });
    test('exemples du cahier des charges', () {
      expect(plain(formatFcfa(213000)), '213 000 FCFA');
      expect(plain(formatFcfa(1248500)), '1 248 500 FCFA');
      expect(plain(formatFcfa(0)), '0 FCFA');
      expect(plain(formatFcfa(-20)), '−20 FCFA');
    });
    test('pourcentage', () => expect(plain(formatPercent(0.5807537)), '58,1 %'));
    test('date en toutes lettres', () => expect(formatLongDate(DateTime(2026, 11, 22)), 'dimanche 22 novembre 2026'));
  });

  group('Âge du lot en jours', () {
    test('bande EL-26-001 au 22/11/2026', () => expect(ageInDays(DateTime(2026, 10, 6), DateTime(2026, 11, 22)), 47));
    test('lot créé aujourd’hui', () => expect(ageInDays(DateTime(2026, 11, 22, 9), DateTime(2026, 11, 22, 8)), 0));
    test('date future → 0', () => expect(ageInDays(DateTime(2026, 12, 1), DateTime(2026, 11, 22)), 0));
  });

  group('Menus dynamiques', () {
    test('la couveuse n’affiche jamais la vaccination', () {
      expect(modulesFor(ProductionType.couveuse), isNot(contains(AppModule.sante)));
      expect(modulesFor(ProductionType.couveuse), contains(AppModule.productionMensuelle));
    });
    test('santé présente pour chair, races améliorées et pondeuses', () {
      for (final p in [ProductionType.chair, ProductionType.ameliorees, ProductionType.pondeuses]) {
        expect(modulesFor(p), contains(AppModule.sante), reason: p.label);
      }
    });
    test('couvaison et conversion seulement si activée', () {
      expect(modulesFor(ProductionType.ameliorees), isNot(contains(AppModule.couvaison)));
      expect(modulesFor(ProductionType.ameliorees, options: {OptionalFeature.couvaisonConversion}),
          contains(AppModule.couvaison));
    });
    test('une option d’une autre production est ignorée', () {
      expect(modulesFor(ProductionType.chair, options: {OptionalFeature.couvaisonConversion}),
          isNot(contains(AppModule.couvaison)));
    });
    test('chair sans ponte ni couveuse', () {
      final m = modulesFor(ProductionType.chair);
      expect(m, isNot(contains(AppModule.ponteOeufs)));
      expect(m, isNot(contains(AppModule.ponteReforme)));
      expect(m, isNot(contains(AppModule.calendrierCouvaison)));
    });
    test('comptabilité commune à toutes les productions', () {
      for (final p in ProductionType.values) {
        expect(modulesFor(p), containsAll([AppModule.ventes, AppModule.depenses, AppModule.comptabilite]));
      }
    });
  });
}
