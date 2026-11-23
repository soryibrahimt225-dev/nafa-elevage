import 'package:material_ui/material_ui.dart';

import '../data/app_data.dart';

/// Accès à toutes les données depuis un écran (lecture ponctuelle).
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.data, this.reload, required super.child});
  final AppData data;

  /// Recharge toutes les données depuis l'appareil (après une restauration).
  final Future<void> Function()? reload;

  static AppData? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()?.data;

  static Future<void> Function()? reloadOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()?.reload;

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.data != data;
}
