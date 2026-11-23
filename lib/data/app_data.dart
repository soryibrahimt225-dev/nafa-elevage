import 'config_store.dart';
import 'egg_store.dart';
import 'finance_store.dart';
import 'health_store.dart';
import 'lot_store.dart';
import 'reminder_service.dart';
import 'settings_store.dart';

/// Toutes les données de l'application, chargées au démarrage.
class AppData {
  AppData({
    required this.settings,
    required this.config,
    required this.lots,
    required this.finance,
    required this.health,
    required this.reminders,
    required this.eggs,
  });

  final FarmSettings settings;
  final ConfigStore config;
  final LotStore lots;
  final FinanceStore finance;
  final HealthStore health;
  final ReminderService reminders;
  final EggStore eggs;

  /// [backend] : accès à l'agenda et aux notifications du téléphone
  /// (remplacé sur le web et dans les tests).
  static Future<AppData> load({ReminderBackend? backend}) async => AppData(
        settings: await FarmSettings.load(),
        config: await ConfigStore.load(),
        lots: await LotStore.load(),
        finance: await FinanceStore.load(),
        health: await HealthStore.load(),
        reminders: await ReminderService.load(backend ?? UnsupportedReminderBackend()),
        eggs: await EggStore.load(),
      );
}
