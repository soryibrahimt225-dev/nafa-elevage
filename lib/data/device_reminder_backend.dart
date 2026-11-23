import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminders.dart';
import 'reminder_service.dart';

/// Rappels sur Android et iPhone : agenda natif du téléphone (sans exiger
/// Google Agenda) et notifications locales de l'application.
class DeviceReminderBackend implements ReminderBackend {
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationDetails(
    'nafa_couvaison',
    'Couvaison',
    channelDescription: 'Rappels de descente des œufs et d’éclosion',
    importance: Importance.high,
    priority: Priority.high,
  );

  @override
  bool get supported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Bamako'));
    }
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestCalendar() async {
    try {
      final s = await DeviceCalendar.instance.requestPermissions();
      return s == CalendarPermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> createCalendarEvent(PlannedReminder r, {required bool dayBefore}) =>
      DeviceCalendar.instance.createEvent(
        title: r.title,
        description: r.body,
        startDate: r.eventDate,
        endDate: r.eventDate.add(const Duration(minutes: 30)),
        reminders: [if (dayBefore) const Duration(days: 1), Duration.zero],
      );

  @override
  Future<void> deleteCalendarEvent(String id) => DeviceCalendar.instance.deleteEvent(instanceId: id);

  @override
  Future<bool> requestNotifications() async {
    await _init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _notifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true, badge: true) ??
        false;
  }

  @override
  Future<void> scheduleNotification(PlannedReminder r) async {
    await _init();
    final at = r.alertAt;
    await _notifications.zonedSchedule(
      id: r.notificationId,
      title: r.title,
      body: r.body,
      scheduledDate: tz.TZDateTime(tz.local, at.year, at.month, at.day, at.hour, at.minute),
      notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
      // Heure approximative : pas besoin de l'autorisation « alarmes exactes ».
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelNotification(int id) async {
    await _init();
    await _notifications.cancel(id: id);
  }
}
