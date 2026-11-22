import 'package:material_ui/material_ui.dart';

import 'data/app_data.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(NafaApp(data: await AppData.load()));
}

class NafaApp extends StatelessWidget {
  const NafaApp({super.key, required this.data, this.today});
  final AppData data;

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
        listenable: data.settings,
        builder: (context, _) => data.settings.isConfigured
            ? HomeShell(data: data, today: today)
            : OnboardingScreen(settings: data.settings),
      ),
    );
  }
}
