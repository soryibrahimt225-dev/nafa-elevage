import 'package:material_ui/material_ui.dart';

import 'data/app_data.dart';
import 'data/device_reminder_backend.dart';
import 'ui/app_scope.dart';
import 'ui/config_scope.dart';
import 'ui/reminder_scope.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(NafaApp(data: await AppData.load(backend: DeviceReminderBackend())));
}

class NafaApp extends StatelessWidget {
  const NafaApp({super.key, required this.data, this.today});
  final AppData data;

  /// Date du jour imposée (tests). Par défaut : date du téléphone.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      data: data,
      child: ConfigScope(
      config: data.config,
      child: ReminderScope(
      reminders: data.reminders,
      child: MaterialApp(
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
      ),
      ),
      ),
    );
  }
}
