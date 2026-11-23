import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/app_data.dart';
import 'package:nafa_elevage/data/settings_store.dart';
import 'package:nafa_elevage/main.dart';
import 'package:nafa_elevage/data/reminder_service.dart';

import 'fake_reminder_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FarmSettings> freshSettings([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return FarmSettings.load();
}

Future<void> enterKey(WidgetTester t, String key, String text) async {
  final f = find.byKey(ValueKey(key));
  await t.scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.enterText(find.descendant(of: f, matching: find.byType(EditableText)), text);
  await t.pump();
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  await t.scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pump();
}

void main() {
  final today = DateTime(2026, 11, 22);

  Future<void> pumpPhone(WidgetTester t, FarmSettings s, {ReminderBackend? backend}) async {
    t.view.physicalSize = const Size(360, 740);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final data = await t.runAsync(() => AppData.load(backend: backend));
    await t.pumpWidget(NafaApp(data: data!, today: today));
    await t.pumpAndSettle();
  }

  testWidgets('Onboarding → couveuse : pas de vaccination dans le menu', (t) async {
    final s = await freshSettings();
    await pumpPhone(t, s);
    expect(find.text('Quelle production voulez-vous gérer ?'), findsOneWidget);

    await tapKey(t, 'production-couveuse');
    // Aucune option proposée pour la couveuse.
    expect(find.byType(CheckboxListTile), findsNothing);
    await tapKey(t, 'continuer');
    await t.pumpAndSettle();

    expect(find.byType(DrawerButton), findsOneWidget);
    await t.tap(find.byType(DrawerButton));
    await t.pumpAndSettle();
    expect(find.text('Santé et vaccination'), findsNothing);
    expect(find.text('Calendrier de couvaison'), findsOneWidget);
    expect(find.text('Production mensuelle'), findsOneWidget);
  });

  testWidgets('Races améliorées avec couvaison activée', (t) async {
    final s = await freshSettings();
    await pumpPhone(t, s);
    await tapKey(t, 'production-ameliorees');
    await tapKey(t, 'option-couvaisonConversion');
    await tapKey(t, 'continuer');
    await t.pumpAndSettle();

    await t.tap(find.byType(DrawerButton));
    await t.pumpAndSettle();
    expect(find.text('Couvaison et conversion'), findsOneWidget);
    expect(find.text('Santé et vaccination'), findsOneWidget);
  });

  testWidgets('Tableau de bord : montants complets, aucun mot « oiseau »', (t) async {
    final s = await freshSettings({'nafa.production': 'chair'});
    await pumpPhone(t, s);
    expect(find.text('0 FCFA'), findsNWidgets(3));
    expect(find.textContaining(RegExp('oiseau', caseSensitive: false)), findsNothing);
    expect(t.takeException(), isNull); // pas de débordement sur petit écran
  });

  testWidgets('Calendrier de couvaison : 22/11 → descente 8/12, éclosion 13/12', (t) async {
    final s = await freshSettings({'nafa.production': 'couveuse'});
    await pumpPhone(t, s);
    await t.tap(find.byType(DrawerButton));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('menu-calendrierCouvaison')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('13 décembre 2026 · Jour 21'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('8 décembre 2026 · Jour 16'), findsOneWidget);
    expect(find.text('13 décembre 2026 · Jour 21'), findsOneWidget);
  });

  testWidgets('Le choix est conservé au redémarrage', (t) async {
    final s = await freshSettings({'nafa.production': 'pondeuses'});
    await pumpPhone(t, s);
    expect(find.text('Pondeuses'), findsWidgets);
    expect(find.text('Quelle production voulez-vous gérer ?'), findsNothing);
  });

  Future<void> openMenu(WidgetTester t, String module) async {
    await t.tap(find.byType(DrawerButton));
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey('menu-$module')));
    await t.pumpAndSettle();
  }

  testWidgets('Créer un lot de chair, puis enregistrer une mortalité', (t) async {
    final s = await freshSettings({'nafa.production': 'chair'});
    await pumpPhone(t, s);
    await openMenu(t, 'lots');
    expect(find.text('Aucun lot'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('nouveau-lot')));
    await t.pumpAndSettle();
    expect(find.text('CHA-26-001'), findsOneWidget); // code automatique
    await t.tap(find.text('Cobb 500')); // choix rapide de la race
    await t.pump();
    await enterKey(t, 'effectif', '500');
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    expect(find.textContaining('CHA-26-001 · Cobb 500'), findsOneWidget);
    expect(find.textContaining('500 sujets sur 500'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('lot-CHA-26-001')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('saisir-sortie')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('nombre-sortie')), '12');
    await t.tap(find.byKey(const ValueKey('valider-sortie')));
    await t.pumpAndSettle();
    expect(find.text('488 sujets'), findsOneWidget);
    expect(find.textContaining('2,4\u00A0%'), findsOneWidget);
  });

  testWidgets('Saisie impossible : plus de morts que de sujets', (t) async {
    final s = await freshSettings({'nafa.production': 'pondeuses'});
    await pumpPhone(t, s);
    await openMenu(t, 'lots');
    await t.tap(find.byKey(const ValueKey('nouveau-lot')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('race')), 'ISA Brown');
    await enterKey(t, 'effectif', '10');
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('lot-PON-26-001')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('saisir-sortie')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('nombre-sortie')), '11');
    await t.tap(find.byKey(const ValueKey('valider-sortie')));
    await t.pumpAndSettle();
    expect(find.text('Maximum : 10'), findsOneWidget);
  });

  testWidgets('Couveuse : mettre des œufs, voir les dates, saisir l’éclosion', (t) async {
    final s = await freshSettings({'nafa.production': 'couveuse'});
    await pumpPhone(t, s);
    await openMenu(t, 'lotsOeufs');
    await t.tap(find.byKey(const ValueKey('nouveau-lot-oeufs')));
    await t.pumpAndSettle();
    expect(find.text('BUR-26-001'), findsOneWidget);
    await enterKey(t, 'oeufs', '120');
    await t.pump();
    await t.scrollUntilVisible(find.text('13 décembre 2026 · jour 21'), 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('8 décembre 2026 · jour 16'), findsOneWidget);
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    expect(find.textContaining('BUR-26-001 · Goliath'), findsOneWidget);
    await t.pump(const Duration(seconds: 5)); // le message de confirmation disparaît
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('lot-BUR-26-001')));
    await t.pumpAndSettle();
    await tapKey(t, 'saisir-eclosion');
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('eclos')), '90');
    await t.enterText(find.byKey(const ValueKey('morts')), '3');
    await t.tap(find.byKey(const ValueKey('valider-eclosion')));
    await t.pumpAndSettle();
    expect(find.text('75,0\u00A0%'), findsOneWidget);
    expect(find.text('87'), findsNWidgets(2)); // poussins vivants et disponibles
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    await openMenu(t, 'tableauDeBord');
    expect(find.text('75,0\u00A0%'), findsOneWidget); // taux d'éclosion du tableau de bord
  });

  testWidgets('Vente de sujets liée au lot : effectif, comptabilité et tableau de bord', (t) async {
    final s = await freshSettings({'nafa.production': 'chair'});
    await pumpPhone(t, s);
    await openMenu(t, 'lots');
    await t.tap(find.byKey(const ValueKey('nouveau-lot')));
    await t.pumpAndSettle();
    await t.tap(find.text('Cobb 500'));
    await t.pump();
    await enterKey(t, 'effectif', '200');
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();

    await openMenu(t, 'ventes');
    expect(find.text('Aucune vente'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nouvelle-vente')));
    await t.pumpAndSettle();
    // Lot proposé pour une vente de sujets
    await t.tap(find.text('Aucun lot'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('CHA-26-001 · Cobb 500').last);
    await t.pumpAndSettle();
    await enterKey(t, 'quantite', '50');
    await enterKey(t, 'prix', '3500');
    expect(find.text('175\u00A0000\u00A0FCFA'), findsOneWidget); // montant calculé
    await tapKey(t, 'paye-totalite'); // paiement partiel
    await enterKey(t, 'encaisse', '100000');
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    expect(find.textContaining('reste à recouvrer : 75\u00A0000\u00A0FCFA'), findsOneWidget);

    await openMenu(t, 'lots');
    expect(find.textContaining('150 sujets sur 200'), findsOneWidget);

    await openMenu(t, 'depenses');
    await t.tap(find.byKey(const ValueKey('nouvelle-depense')));
    await t.pumpAndSettle();
    await enterKey(t, 'prix', '28500');
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();

    await openMenu(t, 'comptabilite');
    expect(find.text('146\u00A0500\u00A0FCFA'), findsWidgets); // bénéfice 175 000 − 28 500
    await openMenu(t, 'tableauDeBord');
    expect(find.text('175\u00A0000\u00A0FCFA'), findsOneWidget);
    expect(find.text('146\u00A0500\u00A0FCFA'), findsOneWidget);
  });

  testWidgets('Santé : prévoir un soin en retard, il apparaît au tableau de bord', (t) async {
    final s = await freshSettings({
      'nafa.production': 'ameliorees',
      'nafa.lots.v1': '{"animal":[{"id":"1","code":"AME-26-001","production":"ameliorees","breed":"Goliath",'
          '"startDate":"2026-10-01","initialCount":100,"movements":[]}],"incubation":[]}',
    });
    await pumpPhone(t, s);
    await openMenu(t, 'sante');
    await t.tap(find.byKey(const ValueKey('nouveau-soin')));
    await t.pumpAndSettle();
    await enterKey(t, 'soin-nom', 'Vaccin A');
    expect(find.text('Âge du lot à cette date : 52 jours'), findsOneWidget);
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    expect(find.text('Aujourd’hui'), findsOneWidget);
    await openMenu(t, 'tableauDeBord');
    expect(find.textContaining('AME-26-001 · Vaccin A'), findsOneWidget);
  });

  testWidgets('Paramètres : la durée modifiée change les dates du nouveau lot', (t) async {
    final s = await freshSettings({'nafa.production': 'couveuse'});
    await pumpPhone(t, s);
    await openMenu(t, 'parametres');
    await tapKey(t, 'espece-goliath');
    await t.pumpAndSettle();
    await t.enterText(find.descendant(of: find.byKey(const ValueKey('jour-descente')), matching: find.byType(EditableText)), '18');
    await t.tap(find.byKey(const ValueKey('valider-espece')));
    await t.pumpAndSettle();
    expect(find.text('21 jours · descente au jour 18'), findsNWidgets(2)); // Goliath et poulet local

    await openMenu(t, 'lotsOeufs');
    await t.tap(find.byKey(const ValueKey('nouveau-lot-oeufs')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('10 décembre 2026 · jour 18'), 120, scrollable: find.byType(Scrollable).first);
    expect(find.text('10 décembre 2026 · jour 18'), findsOneWidget);
  });

  testWidgets('Paramètres : prix de référence proposé à la vente', (t) async {
    final s = await freshSettings({'nafa.production': 'couveuse'});
    await pumpPhone(t, s);
    await openMenu(t, 'parametres');
    await tapKey(t, 'prix-poussins');
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('valeur-prix')), '750');
    await t.tap(find.byKey(const ValueKey('valider-prix')));
    await t.pumpAndSettle();
    expect(find.text('750\u00A0FCFA par poussin'), findsOneWidget);

    await openMenu(t, 'ventes');
    await t.tap(find.byKey(const ValueKey('nouvelle-vente')));
    await t.pumpAndSettle();
    await enterKey(t, 'quantite', '10');
    expect(find.text('7\u00A0500\u00A0FCFA'), findsOneWidget);
  });

  testWidgets('Races améliorées : repères du cycle sur la fiche du lot', (t) async {
    final s = await freshSettings({
      'nafa.production': 'ameliorees',
      'nafa.lots.v1': '{"animal":[{"id":"1","code":"AME-26-001","production":"ameliorees","breed":"Goliath",'
          '"startDate":"2026-10-01","initialCount":100,"objective":"ponte","movements":[]}],"incubation":[]}',
    });
    await pumpPhone(t, s);
    await openMenu(t, 'lots');
    await t.tap(find.byKey(const ValueKey('lot-AME-26-001')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Cycle Goliath'), 120, scrollable: find.byType(Scrollable).first);
    expect(find.text('1 février 2027'), findsOneWidget); // sélection à 4 mois
    expect(find.text('1 octobre 2028'), findsOneWidget); // contrôle de réforme à 24 mois
  });

  testWidgets('Téléphone : après le lot, rappels dans l’agenda ; supprimés à l’éclosion', (t) async {
    final s = await freshSettings({'nafa.production': 'couveuse'});
    final phone = FakeReminderBackend();
    await pumpPhone(t, s, backend: phone);
    await openMenu(t, 'lotsOeufs');
    await t.tap(find.byKey(const ValueKey('nouveau-lot-oeufs')));
    await t.pumpAndSettle();
    await enterKey(t, 'oeufs', '100');
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    expect(find.text('Rappels dans l’agenda ?'), findsOneWidget);
    await t.tap(find.text('Ajouter à l’agenda'));
    await t.pumpAndSettle();
    expect(phone.events.length, 2);
    expect(find.textContaining('2 rappel(s) ajouté(s) à l’agenda'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('lot-BUR-26-001')));
    await t.pumpAndSettle();
    expect(find.text('Agenda du téléphone'), findsOneWidget);
    await tapKey(t, 'saisir-eclosion');
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('eclos')), '80');
    await t.tap(find.byKey(const ValueKey('valider-eclosion')));
    await t.pumpAndSettle();
    expect(phone.events, isEmpty);
  });

  testWidgets('Téléphone : agenda refusé → notification', (t) async {
    final s = await freshSettings({'nafa.production': 'couveuse'});
    final phone = FakeReminderBackend(calendarGranted: false);
    await pumpPhone(t, s, backend: phone);
    await openMenu(t, 'lotsOeufs');
    await t.tap(find.byKey(const ValueKey('nouveau-lot-oeufs')));
    await t.pumpAndSettle();
    await enterKey(t, 'oeufs', '100');
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    await t.tap(find.text('Ajouter à l’agenda'));
    await t.pumpAndSettle();
    expect(phone.notifications.length, 2);
    expect(find.textContaining('Agenda refusé : 2 notification(s)'), findsOneWidget);
  });

  testWidgets('Pondeuses : saisir la ponte, réformer, tableau de bord', (t) async {
    final s = await freshSettings({
      'nafa.production': 'pondeuses',
      'nafa.lots.v1': '{"animal":[{"id":"1","code":"PON-26-001","production":"pondeuses","breed":"ISA Brown",'
          '"startDate":"2026-06-01","initialCount":500,"movements":[]}],"incubation":[]}',
    });
    await pumpPhone(t, s);
    await openMenu(t, 'ponteOeufs');
    expect(find.text('pas encore saisi'), findsOneWidget);
    await tapKey(t, 'saisir-ponte-PON-26-001');
    await t.pumpAndSettle();
    await t.enterText(find.descendant(of: find.byKey(const ValueKey('ramasses')), matching: find.byType(EditableText)), '501');
    await t.tap(find.byKey(const ValueKey('valider-ponte')));
    await t.pumpAndSettle();
    expect(find.text('Maximum : 500'), findsOneWidget); // pas plus d'œufs que de sujets
    await t.enterText(find.descendant(of: find.byKey(const ValueKey('ramasses')), matching: find.byType(EditableText)), '430');
    await t.tap(find.byKey(const ValueKey('valider-ponte')));
    await t.pumpAndSettle();
    expect(find.textContaining('430 œufs · 86,0'), findsOneWidget);

    await tapKey(t, 'reformer-PON-26-001');
    await t.pumpAndSettle();
    await t.enterText(find.descendant(of: find.byKey(const ValueKey('nombre-reforme')), matching: find.byType(EditableText)), '20');
    await t.tap(find.byKey(const ValueKey('valider-reforme')));
    await t.pumpAndSettle();
    expect(find.textContaining('480 · '), findsOneWidget);

    await openMenu(t, 'tableauDeBord');
    expect(find.text('430 œufs'), findsOneWidget);
  });

  testWidgets('Races améliorées : seuls les lots gardés pour la ponte apparaissent', (t) async {
    final s = await freshSettings({
      'nafa.production': 'ameliorees',
      'nafa.lots.v1': '{"animal":['
          '{"id":"1","code":"AME-26-001","production":"ameliorees","breed":"Goliath","startDate":"2026-05-01","initialCount":60,"objective":"ponte","movements":[]},'
          '{"id":"2","code":"AME-26-002","production":"ameliorees","breed":"Goliath","startDate":"2026-09-01","initialCount":80,"objective":"engraissement","movements":[]}'
          '],"incubation":[]}',
    });
    await pumpPhone(t, s);
    await openMenu(t, 'ponteReforme');
    await t.scrollUntilVisible(find.textContaining('AME-26-001'), 150, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('AME-26-001'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const ValueKey('reformer-AME-26-001')), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('AME-26-002'), findsNothing);
  });

  testWidgets('Alimentation : aliment, achat avec dépense, distribution par ration', (t) async {
    final s = await freshSettings({
      'nafa.production': 'pondeuses',
      'nafa.lots.v1': '{"animal":[{"id":"1","code":"PON-26-001","production":"pondeuses","breed":"ISA Brown",'
          '"startDate":"2026-06-01","initialCount":400,"movements":[]}],"incubation":[]}',
    });
    await pumpPhone(t, s);
    await openMenu(t, 'alimentation');
    expect(find.text('Aucun aliment'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nouvel-aliment')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('nom-aliment')), 'Aliment pondeuse');
    await t.tap(find.byKey(const ValueKey('valider-aliment')));
    await t.pumpAndSettle();

    await tapKey(t, 'achat-Aliment pondeuse');
    await t.pumpAndSettle();
    await t.enterText(find.descendant(of: find.byKey(const ValueKey('sacs')), matching: find.byType(EditableText)), '2');
    await t.enterText(find.descendant(of: find.byKey(const ValueKey('prix-sac')), matching: find.byType(EditableText)), '28500');
    await t.tap(find.byKey(const ValueKey('valider-achat')));
    await t.pumpAndSettle();
    expect(find.textContaining('100\u00A0kg · 2,0 sac(s)'), findsOneWidget);

    await tapKey(t, 'distribuer-Aliment pondeuse');
    await t.pumpAndSettle();
    await t.enterText(find.descendant(of: find.byKey(const ValueKey('g-par-sujet')), matching: find.byType(EditableText)), '115');
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Calculer : 400 × 115 g = 46\u00A0kg'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('valider-distribution')));
    await t.pumpAndSettle();
    expect(find.textContaining('54\u00A0kg · 1,1 sac(s)'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Consommation par lot'), 150, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('46\u00A0kg · 26\u00A0220\u00A0FCFA'), findsOneWidget); // 46 kg × 570 FCFA/kg

    await openMenu(t, 'depenses');
    expect(find.text('57\u00A0000\u00A0FCFA'), findsWidgets); // dépense créée avec l'achat
  });

  testWidgets('Couveuse : garder des poussins, puis vente limitée aux disponibles', (t) async {
    final s = await freshSettings({
      'nafa.production': 'couveuse',
      'nafa.lots.v1': '{"animal":[],"incubation":[{"id":"1","code":"BUR-26-025","ownerType":"producteur",'
          '"ownerName":"Producteur","speciesLabel":"Goliath","entryDate":"2026-10-18","eggsSet":107,'
          '"incubationDays":21,"descenteDay":16,"hatched":75,"chickDeaths":0}]}',
    });
    await pumpPhone(t, s);
    await openMenu(t, 'poussinsGardes');
    expect(find.text('75 poussins'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nouvelle-bande')));
    await t.pumpAndSettle();
    expect(find.text('EL-26-001'), findsOneWidget);
    await enterKey(t, 'garder-BUR-26-025', '30');
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    expect(find.text('45 poussins'), findsOneWidget);
    await t.scrollUntilVisible(find.textContaining('Origine : BUR-26-025 (30)'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Origine : BUR-26-025 (30)'), findsOneWidget);

    await openMenu(t, 'ventes');
    await t.tap(find.byKey(const ValueKey('nouvelle-vente')));
    await t.pumpAndSettle();
    await t.tap(find.text('Aucun lot'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('BUR-26-025 · 45 poussins disponibles').last);
    await t.pumpAndSettle();
    await enterKey(t, 'quantite', '50');
    await enterKey(t, 'prix', '700');
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    expect(find.textContaining('Il ne reste que 45 poussins disponibles'), findsOneWidget);
    await t.pump(const Duration(seconds: 5)); // le message d'erreur disparaît
    await t.pumpAndSettle();
    await enterKey(t, 'quantite', '45');
    await tapKey(t, 'enregistrer');
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();

    await openMenu(t, 'poussinsGardes');
    expect(find.textContaining('Aucun poussin à répartir'), findsOneWidget);
    await openMenu(t, 'tableauDeBord');
    await t.scrollUntilVisible(find.text('Poussins gardés'), 150, scrollable: find.byType(Scrollable).first);
    expect(find.text('30 sujets'), findsOneWidget);
  });
}
