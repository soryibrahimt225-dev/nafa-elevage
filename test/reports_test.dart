import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/app_data.dart';
import 'package:nafa_elevage/data/report_builder.dart';
import 'package:nafa_elevage/data/report_export.dart';
import 'package:nafa_elevage/domain/eggs.dart';
import 'package:nafa_elevage/domain/feed.dart';
import 'package:nafa_elevage/domain/finance.dart';
import 'package:nafa_elevage/domain/lots.dart';
import 'package:nafa_elevage/domain/production.dart';
import 'package:nafa_elevage/domain/report.dart';
import 'package:shared_preferences/shared_preferences.dart';

String plain(String s) => s.replaceAll(' ', ' ');
String row(Report r, String section, String label) =>
    plain(r.sections.firstWhere((s) => s.title == section).rows.firstWhere((x) => x.$1 == label).$2.display);

Future<AppData> pondeusesFarm() async {
  SharedPreferences.setMockInitialValues({'nafa.production': 'pondeuses'});
  final d = await AppData.load();
  final lot = AnimalLot(id: '1', code: 'PON-26-001', production: ProductionType.pondeuses, breed: 'ISA Brown',
      startDate: DateTime(2026, 6, 1), initialCount: 500)
    ..addMovement(Movement(date: DateTime(2026, 11, 10), type: MovementType.mortalite, count: 20));
  await d.lots.addAnimalLot(lot);
  await d.lots.addAnimalLot(AnimalLot(id: '2', code: 'PON-26-002', production: ProductionType.pondeuses,
      breed: 'Hisex', startDate: DateTime(2026, 9, 1), initialCount: 200));
  // Aliment : 100 kg achetés 57 000 FCFA (570 FCFA/kg), 46 kg distribués au lot 1.
  await d.feed.saveItem(FeedItem(id: 'a', name: 'Aliment pondeuse', stage: FeedStage.pondeuse));
  await d.feed.addMove(FeedMove(id: 'm1', itemId: 'a', date: DateTime(2026, 11, 11), type: FeedMoveType.achat,
      grams: 100000, cost: 57000));
  await d.feed.addMove(FeedMove(id: 'm2', itemId: 'a', date: DateTime(2026, 11, 20), type: FeedMoveType.distribution,
      grams: 46000, lotCode: 'PON-26-001'));
  await d.finance.addExpense(Expense(id: 'e1', date: DateTime(2026, 11, 11), category: ExpenseCategory.aliment,
      quantity: 2, unitPrice: 28500, amountPaid: 57000, production: ProductionType.pondeuses));
  await d.finance.addExpense(Expense(id: 'e2', date: DateTime(2026, 10, 28), category: ExpenseCategory.mainOeuvre,
      quantity: 1, unitPrice: 10000, amountPaid: 10000));
  await d.finance.addSale(Sale(id: 's1', date: DateTime(2026, 11, 21), category: SaleCategory.oeufsTable,
      quantity: 900, unitPrice: 100, amountPaid: 60000, production: ProductionType.pondeuses, lotCode: 'PON-26-001',
      client: 'Client A'));
  await d.eggs.save(EggRecord(lotCode: 'PON-26-001', date: DateTime(2026, 11, 21), collected: 430, broken: 5));
  await d.eggs.save(EggRecord(lotCode: 'PON-26-001', date: DateTime(2026, 11, 22), collected: 440, broken: 5));
  return d;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final today = DateTime(2026, 11, 23);

  test('Rapports proposés selon la production', () {
    expect(reportKindsFor(ProductionType.chair, {}), isNot(contains(ReportKind.ponte)));
    expect(reportKindsFor(ProductionType.couveuse, {}), containsAll([ReportKind.couvaison, ReportKind.lot]));
    expect(reportKindsFor(ProductionType.couveuse, {}), isNot(contains(ReportKind.race)));
    expect(reportKindsFor(ProductionType.ameliorees, {OptionalFeature.couvaisonConversion}), contains(ReportKind.couvaison));
  });

  test('Rapport financier : totaux, dépenses générales à part, reste à recouvrer', () async {
    final d = await pondeusesFarm();
    final r = ReportBuilder(d, today: today).financial();
    expect(row(r, 'Résultat', 'Chiffre d’affaires'), '90 000 FCFA');
    expect(row(r, 'Résultat', 'Dépenses'), '67 000 FCFA');
    expect(row(r, 'Résultat', 'Bénéfice'), '23 000 FCFA');
    expect(row(r, 'Résultat', 'Reste à recouvrer'), '30 000 FCFA');
    final byProd = r.sections.firstWhere((s) => s.title == 'Résultat par production').table!;
    expect(byProd.rows.map((x) => plain(x.first.display)), ['Pondeuses', 'Toute la ferme (dépenses générales)']);
    expect(r.sections.any((s) => s.title == 'Évolution mensuelle'), isTrue);
    final nov = ReportBuilder(d, today: today).financial(month: DateTime(2026, 11));
    expect(row(nov, 'Résultat', 'Dépenses'), '57 000 FCFA');
  });

  test('Rapport du lot : aliment compté une seule fois', () async {
    final d = await pondeusesFarm();
    final r = ReportBuilder(d, today: today).lot('PON-26-001');
    expect(row(r, 'Effectif', 'Effectif actuel'), '480');
    expect(row(r, 'Effectif', 'Taux de mortalité'), '4,0 %');
    expect(row(r, 'Alimentation', 'Aliment distribué'), '46 kg');
    expect(row(r, 'Alimentation', 'Coût de l’aliment distribué'), '26 220 FCFA');
    expect(row(r, 'Ponte', 'Œufs de table'), '860');
    // 90 000 de ventes − 0 dépense rattachée − 26 220 d'aliment
    expect(row(r, 'Résultat du lot', 'Résultat'), '63 780 FCFA');
  });

  test('Rapport par race et de ponte', () async {
    final d = await pondeusesFarm();
    final race = ReportBuilder(d, today: today).byBreed().sections.single.table!;
    expect(race.rows.map((x) => x.first.display).toSet(), {'Hisex', 'ISA Brown'});
    final ponte = ReportBuilder(d, today: today).laying(month: DateTime(2026, 11));
    expect(row(ponte, 'Synthèse', 'Œufs ramassés'), '870');
    expect(row(ponte, 'Synthèse', 'Œufs vendus'), '900');
    // 870 œufs pour 2 jours × 480 sujets
    expect(row(ponte, 'Synthèse', 'Taux de ponte moyen'), '90,6 %');
  });

  test('Rapport de couvaison (lots de juin du classeur)', () async {
    SharedPreferences.setMockInitialValues({'nafa.production': 'couveuse'});
    final d = await AppData.load();
    IncubationLot l(String c, DateTime e, int eggs, {int? h, int? m, OwnerType o = OwnerType.producteur}) =>
        IncubationLot(id: c, code: c, ownerType: o, ownerName: o.label, speciesLabel: 'Goliath', entryDate: e,
            eggsSet: eggs, incubationDays: 21, descenteDay: 16, hatched: h, chickDeaths: m);
    await d.lots.addIncubationLots([
      l('BUR-26-001', DateTime(2026, 5, 14), 42),
      l('BUR-26-002', DateTime(2026, 5, 23), 24, h: 6, m: 1),
      l('BUR-26-003', DateTime(2026, 5, 24), 24, h: 7, m: 1),
      l('BUR-26-004', DateTime(2026, 5, 31), 79),
      l('BUR-26-005', DateTime(2026, 6, 3), 60, h: 27, m: 5),
      l('BUR-26-006', DateTime(2026, 6, 7), 58, h: 25),
      l('BUR-26-008', DateTime(2026, 5, 31), 79, h: 18),
      l('CLI-26-001', DateTime(2026, 7, 14), 26, o: OwnerType.client),
    ]);
    final r = ReportBuilder(d, today: today).hatching(month: DateTime(2026, 6));
    expect(row(r, 'Mes lots', 'Œufs mis en couveuse'), '366');
    expect(row(r, 'Mes lots', 'Poussins éclos'), '83');
    expect(row(r, 'Mes lots', 'Taux d’éclosion'), '33,9 %');
    expect(row(r, 'Mes lots', 'Poussins vivants'), '76');
    expect(row(r, 'Mes lots', 'Poussins disponibles'), '76');
    expect(row(r, 'Lots clients', 'Lots'), '0');
    final m = ReportBuilder(d, today: today).monthly(DateTime(2026, 6));
    expect(m.sections.map((s) => s.title), contains('Mes lots'));
  });

  group('Exports', () {
    test('PDF : fichier valide, police embarquée', () async {
      final d = await pondeusesFarm();
      final r = ReportBuilder(d, today: today).monthly(DateTime(2026, 11));
      final fonts = ReportFonts.fromBytes(
        ByteData.sublistView(File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync()),
        ByteData.sublistView(File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync()),
      );
      final bytes = await reportToPdf(r, fonts, logo: File('assets/images/nafa_logo.png').readAsBytesSync());
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(10000));
    });
    test('Excel : nombres écrits comme nombres', () async {
      final d = await pondeusesFarm();
      final r = ReportBuilder(d, today: today).financial();
      final book = xl.Excel.decodeBytes(reportToXlsx(r));
      final sheet = book.tables['Rapport']!;
      expect(sheet.row(0).first!.value.toString(), 'Rapport financier');
      final ca = sheet.rows.firstWhere((x) => x.isNotEmpty && x.first?.value.toString() == 'Chiffre d’affaires');
      expect(ca[1]!.value, isA<xl.IntCellValue>());
      expect((ca[1]!.value! as xl.IntCellValue).value, 90000);
      expect(ca[2]!.value.toString(), 'FCFA');
    });
    test('Nom de fichier', () {
      final r = Report(title: 'Rapport du lot PON-26-001', subtitle: '', generatedAt: DateTime(2026, 11, 23), sections: []);
      expect(r.fileName('pdf'), 'rapport-du-lot-pon-26-001-2026-11-23.pdf');
      expect(Report(title: 'Rapport de ponte', subtitle: '', generatedAt: DateTime(2026, 1, 5), sections: []).fileName('xlsx'),
          'rapport-de-ponte-2026-01-05.xlsx');
    });
  });
}
