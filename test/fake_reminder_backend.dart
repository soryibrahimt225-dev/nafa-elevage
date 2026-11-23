import 'package:nafa_elevage/data/reminder_service.dart';
import 'package:nafa_elevage/domain/reminders.dart';

/// Téléphone simulé pour les tests.
class FakeReminderBackend implements ReminderBackend {
  FakeReminderBackend({this.calendarGranted = true, this.calendarFails = false});
  bool calendarGranted;
  bool calendarFails;
  final Map<String, PlannedReminder> events = {};
  final Map<int, PlannedReminder> notifications = {};
  var _n = 0;

  @override
  bool get supported => true;
  @override
  Future<bool> requestCalendar() async => calendarGranted;
  @override
  Future<String> createCalendarEvent(PlannedReminder r, {required bool dayBefore}) async {
    if (calendarFails && events.isNotEmpty) throw StateError('agenda indisponible');
    final id = 'evt${_n++}';
    events[id] = r;
    return id;
  }

  @override
  Future<void> deleteCalendarEvent(String id) async => events.remove(id);
  @override
  Future<bool> requestNotifications() async => true;
  @override
  Future<void> scheduleNotification(PlannedReminder r) async => notifications[r.notificationId] = r;
  @override
  Future<void> cancelNotification(int id) async => notifications.remove(id);
}
