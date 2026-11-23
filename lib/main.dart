import 'package:material_ui/material_ui.dart';

import 'data/app_data.dart';
import 'data/device_reminder_backend.dart';
import 'data/reminder_service.dart';
import 'ui/app_scope.dart';
import 'ui/config_scope.dart';
import 'ui/reminder_scope.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_screen.dart';
import 'ui/start_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = DeviceReminderBackend();
  runApp(NafaRoot(initial: await AppData.load(backend: backend), backend: backend));
}

/// Racine de l'application : permet de tout recharger après une
/// restauration de sauvegarde.
class NafaRoot extends StatefulWidget {
  const NafaRoot({super.key, required this.initial, required this.backend, this.today});
  final AppData initial;
  final ReminderBackend backend;

  /// Date imposée (tests).
  final DateTime? today;

  @override
  State<NafaRoot> createState() => _NafaRootState();
}

class _NafaRootState extends State<NafaRoot> {
  late AppData _data = widget.initial;
  var _generation = 0;

  Future<void> _reload() async {
    final data = await AppData.load(backend: widget.backend);
    setState(() {
      _data = data;
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) =>
      NafaApp(key: ValueKey(_generation), data: _data, onReload: _reload, today: widget.today);
}

class NafaApp extends StatelessWidget {
  const NafaApp({super.key, required this.data, this.today, this.onReload, this.showStartScreen = true});
  final AppData data;

  /// Page de démarrage à l'ouverture (désactivée dans certains tests).
  final bool showStartScreen;

  /// Recharge toutes les données (après une restauration).
  final Future<void> Function()? onReload;

  /// Date du jour imposée (tests). Par défaut : date du téléphone.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      data: data,
      reload: onReload,
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
      home: _Gate(data: data, today: today, showStartScreen: showStartScreen),
      ),
      ),
      ),
    );
  }
}

/// Choix de l'écran : assistant (première fois), page de démarrage (à chaque
/// ouverture), puis tableau de bord. Juste après l'assistant, on va
/// directement au tableau de bord.
class _Gate extends StatefulWidget {
  const _Gate({required this.data, required this.today, required this.showStartScreen});
  final AppData data;
  final DateTime? today;
  final bool showStartScreen;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  late bool _started = !widget.showStartScreen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.data.settings,
        builder: (context, _) {
          final d = widget.data;
          if (!d.settings.isConfigured) {
            _started = true; // après l'assistant : tableau de bord direct
            return OnboardingScreen(data: d, today: widget.today);
          }
          if (!_started) {
            return StartScreen(
              data: d,
              today: widget.today ?? DateTime.now(),
              onStart: () => setState(() => _started = true),
            );
          }
          return HomeShell(data: d, today: widget.today);
        },
      );
}
