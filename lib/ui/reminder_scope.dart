import 'package:material_ui/material_ui.dart';

import '../data/reminder_service.dart';

/// Donne accès au service de rappels depuis les écrans.
class ReminderScope extends InheritedNotifier<ReminderService> {
  const ReminderScope({super.key, required ReminderService reminders, required super.child})
      : super(notifier: reminders);

  static ReminderService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReminderScope>()!.notifier!;

  static ReminderService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ReminderScope>()!.notifier!;
}
