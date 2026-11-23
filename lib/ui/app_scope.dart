import 'package:material_ui/material_ui.dart';

import '../data/app_data.dart';

/// Accès à toutes les données depuis un écran (lecture ponctuelle).
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.data, required super.child});
  final AppData data;

  static AppData? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()?.data;

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.data != data;
}
