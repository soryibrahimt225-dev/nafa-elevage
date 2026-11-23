import 'package:material_ui/material_ui.dart';

import '../data/config_store.dart';

/// Donne accès aux paramètres depuis n'importe quel écran ; les écrans se
/// mettent à jour quand un paramètre change.
class ConfigScope extends InheritedNotifier<ConfigStore> {
  const ConfigScope({super.key, required ConfigStore config, required super.child}) : super(notifier: config);

  static ConfigStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConfigScope>()!.notifier!;

  /// Lecture ponctuelle, sans abonnement (utilisable dans initState).
  static ConfigStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ConfigScope>()!.notifier!;
}
