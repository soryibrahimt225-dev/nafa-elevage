import 'package:flutter_test/flutter_test.dart';
import 'package:nafa_elevage/data/reminder_service.dart';
import 'package:nafa_elevage/domain/lots.dart';
import 'package:nafa_elevage/domain/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_reminder_backend.dart';

IncubationLot lot(String code, DateTime entry, {int? hatched}) => IncubationLot(
    id: code, code: code, ownerType: OwnerType.producteur, ownerName: 'Producteur', speciesLabel: 'Goliath',
    entryDate: entry, eggsSet: 145, incubationDays: 21, descenteDay: 16, hatched: hatched);

void main() {
  final now = DateTime(2026, 11, 23, 9);

  group('Planification', () {
    test('BUR-26-031 : descente le 7/12, éclosion le 12/12 à 7 h', () {
      final p = planReminders(lot('BUR-26-031', DateTime(2026, 11, 21)), const ReminderPrefs(), now);
      expect(p.map((r) => r.alertAt), [DateTime(2026, 12, 7, 7), DateTime(2026, 12, 12, 7)]);
      expect(p.first.title, 'Descendre les œufs · BUR-26-031');
      expect(p.last.body, contains('145 œufs Goliath, jour 21'));
    });
    test('rappel la veille à 18 h', () {
      final p = planReminders(
          lot('BUR-26-031', DateTime(2026, 11, 21)), const ReminderPrefs(hour: 18, dayBefore: true), now);
      expect(p.map((r) => r.alertAt), [DateTime(2026, 12, 6, 18), DateTime(2026, 12, 11, 18)]);
      expect(p.first.eventDate, DateTime(2026, 12, 7, 18));
      expect(p.first.body, startsWith('Demain'));
    });
    test('étape déjà passée ignorée ; lot éclos ou rappels désactivés : rien', () {
      // BUR-26-029 : descente le 22/11 (passée), éclosion le 27/11.
      final p = planReminders(lot('BUR-26-029', DateTime(2026, 11, 6)), const ReminderPrefs(), now);
      expect(p.single.isHatch, isTrue);
      expect(planReminders(lot('X', DateTime(2026, 11, 6), hatched: 80), const ReminderPrefs(), now), isEmpty);
      expect(planReminders(lot('Y', DateTime(2026, 11, 21)), const ReminderPrefs(enabled: false), now), isEmpty);
    });
    test('identifiants stables et distincts', () {
      final a = planReminders(lot('BUR-26-031', DateTime(2026, 11, 21)), const ReminderPrefs(), now);
      final b = planReminders(lot('BUR-26-031', DateTime(2026, 11, 21)), const ReminderPrefs(hour: 9), now);
      expect(a.first.notificationId, b.first.notificationId);
      expect(a.first.notificationId, isNot(a.last.notificationId));
    });
  });

  group('Service de rappels', () {
    late FakeReminderBackend phone;
    late ReminderService service;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      phone = FakeReminderBackend();
      service = ReminderService(await SharedPreferences.getInstance(), phone, clock: () => now);
    });

    test('agenda autorisé : deux événements', () async {
      final o = await service.scheduleForLot(lot('BUR-26-031', DateTime(2026, 11, 21)), const ReminderPrefs());
      expect(o.channel, ReminderChannel.agenda);
      expect(phone.events, hasLength(2));
      expect(phone.notifications, isEmpty);
      expect(service.channelFor('BUR-26-031'), ReminderChannel.agenda);
    });
    test('agenda refusé : notification locale au minimum', () async {
      phone.calendarGranted = false;
      final o = await service.scheduleForLot(lot('BUR-26-031', DateTime(2026, 11, 21)), const ReminderPrefs());
      expect(o.channel, ReminderChannel.notification);
      expect(o.calendarRefused, isTrue);
      expect(phone.notifications, hasLength(2));
    });
    test('erreur de l’agenda : rien de laissé dans l’agenda, repli sur notifications', () async {
      phone.calendarFails = true;
      final o = await service.scheduleForLot(lot('BUR-26-031', DateTime(2026, 11, 21)), const ReminderPrefs());
      expect(o.channel, ReminderChannel.notification);
      expect(phone.events, isEmpty);
    });
    test('suppression (éclosion saisie) et pas de doublon en reprogrammant', () async {
      final l = lot('BUR-26-031', DateTime(2026, 11, 21));
      await service.scheduleForLot(l, const ReminderPrefs());
      await service.scheduleForLot(l, const ReminderPrefs(hour: 6));
      expect(phone.events, hasLength(2));
      expect(phone.events.values.first.eventDate.hour, 6);
      await service.cancelForLot('BUR-26-031');
      expect(phone.events, isEmpty);
      expect(service.channelFor('BUR-26-031'), ReminderChannel.aucun);
    });
    test('mise à jour de tous les lots en cours', () async {
      final n = await service.rescheduleAll([
        lot('BUR-26-031', DateTime(2026, 11, 21)),
        lot('BUR-26-029', DateTime(2026, 11, 6)),
        lot('BUR-26-028', DateTime(2026, 11, 2), hatched: 25),
      ], const ReminderPrefs(useCalendar: false));
      expect(n, 2);
      expect(phone.notifications, hasLength(3));
    });
    test('le suivi survit au redémarrage', () async {
      await service.scheduleForLot(lot('BUR-26-031', DateTime(2026, 11, 21)), const ReminderPrefs());
      final again = ReminderService(await SharedPreferences.getInstance(), phone, clock: () => now);
      expect(again.channelFor('BUR-26-031'), ReminderChannel.agenda);
      await again.cancelForLot('BUR-26-031');
      expect(phone.events, isEmpty);
    });
    test('web : aucun rappel', () async {
      final web = ReminderService(await SharedPreferences.getInstance(), UnsupportedReminderBackend(), clock: () => now);
      final o = await web.scheduleForLot(lot('BUR-26-031', DateTime(2026, 11, 21)), const ReminderPrefs());
      expect(o.channel, ReminderChannel.aucun);
    });
  });
}
