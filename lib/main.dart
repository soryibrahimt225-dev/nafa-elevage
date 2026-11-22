import 'package:material_ui/material_ui.dart';

import 'data/settings_store.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await FarmSettings.load();
  runApp(NafaApp(settings: settings));
}

class NafaApp extends StatelessWidget {
  const NafaApp({super.key, required this.settings, this.today});
  final FarmSettings settings;

  /// Date du jour imposée (tests). Par défaut : date du téléphone.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nafa Élevage',
      debugShowCheckedModeBanner: false,
      theme: buildNafaTheme(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => settings.isConfigured
            ? HomeShell(settings: settings, today: today)
            : OnboardingScreen(settings: settings),
      ),
    );
  }
}
