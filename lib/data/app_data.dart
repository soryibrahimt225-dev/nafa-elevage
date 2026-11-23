import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service.dart';
import 'config_store.dart';
import 'egg_store.dart';
import 'feed_store.dart';
import 'finance_store.dart';
import 'health_store.dart';
import 'lot_store.dart';
import 'reminder_service.dart';
import 'settings_store.dart';
import 'sync_api.dart';
import 'sync_service.dart';
import 'weighing_store.dart';

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
    required this.feed,
    required this.weights,
    required this.backup,
    required this.sync,
  });

  final FarmSettings settings;
  final ConfigStore config;
  final LotStore lots;
  final FinanceStore finance;
  final HealthStore health;
  final ReminderService reminders;
  final EggStore eggs;
  final FeedStore feed;
  final WeighingStore weights;
  final BackupService backup;
  final SyncService sync;

  /// [backend] : accès à l'agenda et aux notifications du téléphone
  /// (remplacé sur le web et dans les tests).
  /// [syncApi] : accès au serveur (remplacé dans les tests).
  static Future<AppData> load({ReminderBackend? backend, SyncApi Function(String url)? syncApi}) async => AppData(
        settings: await FarmSettings.load(),
        config: await ConfigStore.load(),
        lots: await LotStore.load(),
        finance: await FinanceStore.load(),
        health: await HealthStore.load(),
        reminders: await ReminderService.load(backend ?? UnsupportedReminderBackend()),
        eggs: await EggStore.load(),
        feed: await FeedStore.load(),
        weights: await WeighingStore.load(),
        backup: await BackupService.load(),
        sync: SyncService(await SharedPreferences.getInstance(), apiFactory: syncApi),
      );
}
