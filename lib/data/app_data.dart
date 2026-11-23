import 'config_store.dart';
import 'finance_store.dart';
import 'health_store.dart';
import 'lot_store.dart';
import 'settings_store.dart';

/// Toutes les données de l'application, chargées au démarrage.
class AppData {
  AppData({required this.settings, required this.config, required this.lots, required this.finance, required this.health});

  final FarmSettings settings;
  final ConfigStore config;
  final LotStore lots;
  final FinanceStore finance;
  final HealthStore health;

  static Future<AppData> load() async => AppData(
        settings: await FarmSettings.load(),
        config: await ConfigStore.load(),
        lots: await LotStore.load(),
        finance: await FinanceStore.load(),
        health: await HealthStore.load(),
      );
}
