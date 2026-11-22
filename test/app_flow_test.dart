import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/settings_store.dart';
import 'package:nafa_elevage/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FarmSettings> freshSettings([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return FarmSettings.load();
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

  Future<void> pumpPhone(WidgetTester t, FarmSettings s) async {
    t.view.physicalSize = const Size(360, 740);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(NafaApp(settings: s, today: today));
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

    expect(s.isConfigured, isTrue);
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
    expect(find.text('8 décembre 2026 · Jour 16'), findsOneWidget);
    expect(find.text('13 décembre 2026 · Jour 21'), findsOneWidget);
  });

  testWidgets('Le choix est conservé au redémarrage', (t) async {
    final s = await freshSettings({'nafa.production': 'pondeuses'});
    await pumpPhone(t, s);
    expect(find.text('Pondeuses'), findsWidgets);
    expect(find.text('Quelle production voulez-vous gérer ?'), findsNothing);
  });
}
