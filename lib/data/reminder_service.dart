import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/lots.dart';
import '../domain/reminders.dart';

/// Où les rappels d'un lot ont été placés.
enum ReminderChannel {
  agenda('Agenda du téléphone'),
  notification('Notification de l’application'),
  aucun('Aucun rappel');

  const ReminderChannel(this.label);
  final String label;
}

/// Accès aux fonctions du téléphone (agenda natif et notifications locales).
/// Une implémentation de remplacement sert pour le web et les tests.
abstract class ReminderBackend {
  /// Le téléphone permet-il les rappels (faux sur le web) ?
  bool get supported;

  /// Demande l'accès à l'agenda ; vrai si accordé.
  Future<bool> requestCalendar();

  /// Crée un événement d'agenda (avec son alerte) ; renvoie son identifiant.
  Future<String> createCalendarEvent(PlannedReminder r, {required bool dayBefore});
  Future<void> deleteCalendarEvent(String id);

  /// Demande l'autorisation d'afficher des notifications ; vrai si accordée.
  Future<bool> requestNotifications();
  Future<void> scheduleNotification(PlannedReminder r);
  Future<void> cancelNotification(int id);
}

/// Web : pas d'agenda ni de notification programmée.
class UnsupportedReminderBackend implements ReminderBackend {
  @override
  bool get supported => false;
  @override
  Future<bool> requestCalendar() async => false;
  @override
  Future<String> createCalendarEvent(PlannedReminder r, {required bool dayBefore}) =>
      throw UnsupportedError('Agenda indisponible');
  @override
  Future<void> deleteCalendarEvent(String id) async {}
  @override
  Future<bool> requestNotifications() async => false;
  @override
  Future<void> scheduleNotification(PlannedReminder r) async {}
  @override
  Future<void> cancelNotification(int id) async {}
}

/// Rappels créés pour un lot (pour pouvoir les modifier ou les supprimer).
class _LotReminders {
  _LotReminders(this.channel, this.calendarIds, this.notificationIds);
  final ReminderChannel channel;
  final List<String> calendarIds;
  final List<int> notificationIds;

  Map<String, Object?> toJson() => {'channel': channel.name, 'calendar': calendarIds, 'notifications': notificationIds};
  factory _LotReminders.fromJson(Map<String, Object?> j) => _LotReminders(
        ReminderChannel.values.byName(j['channel']! as String),
        (j['calendar'] as List).cast<String>(),
        (j['notifications'] as List).cast<int>(),
      );
}

/// Résultat d'une programmation, pour informer le producteur.
class ReminderOutcome {
  const ReminderOutcome(this.channel, this.count, {this.calendarRefused = false});
  final ReminderChannel channel;
  final int count;

  /// L'accès à l'agenda a été refusé : repli sur les notifications.
  final bool calendarRefused;
}

/// Programme, modifie et supprime les rappels de couvaison.
/// Règle : agenda du téléphone si autorisé, sinon notification locale.
class ReminderService extends ChangeNotifier {
  ReminderService(this._prefs, this.backend, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      for (final e in (jsonDecode(raw) as Map).entries) {
        _byLot[e.key as String] = _LotReminders.fromJson((e.value as Map).cast());
      }
    }
  }

  static const _key = 'nafa.reminders.v1';
  final SharedPreferences _prefs;
  final ReminderBackend backend;
  final DateTime Function() _clock;
  final Map<String, _LotReminders> _byLot = {};

  static Future<ReminderService> load(ReminderBackend backend) async =>
      ReminderService(await SharedPreferences.getInstance(), backend);

  bool get supported => backend.supported;

  ReminderChannel channelFor(String lotCode) => _byLot[lotCode]?.channel ?? ReminderChannel.aucun;

  /// (Re)programme les rappels d'un lot. [useCalendar] peut forcer le choix
  /// fait par le producteur au moment de la création du lot.
  Future<ReminderOutcome> scheduleForLot(IncubationLot lot, ReminderPrefs prefs, {bool? useCalendar}) async {
    await cancelForLot(lot.code, notify: false);
    final plan = planReminders(lot, prefs, _clock());
    if (!backend.supported || plan.isEmpty) {
      await _save();
      return ReminderOutcome(ReminderChannel.aucun, 0);
    }
    var refused = false;
    if (useCalendar ?? prefs.useCalendar) {
      if (await backend.requestCalendar()) {
        final ids = <String>[];
        try {
          for (final r in plan) {
            ids.add(await backend.createCalendarEvent(r, dayBefore: prefs.dayBefore));
          }
          _byLot[lot.code] = _LotReminders(ReminderChannel.agenda, ids, const []);
          await _save();
          return ReminderOutcome(ReminderChannel.agenda, ids.length);
        } catch (_) {
          // Agenda indisponible (aucun calendrier, erreur) : on retire ce qui a
          // été créé et on passe aux notifications.
          for (final id in ids) {
            await backend.deleteCalendarEvent(id);
          }
        }
      } else {
        refused = true;
      }
    }
    // Repli minimum : notification locale.
    await backend.requestNotifications();
    for (final r in plan) {
      await backend.scheduleNotification(r);
    }
    _byLot[lot.code] =
        _LotReminders(ReminderChannel.notification, const [], [for (final r in plan) r.notificationId]);
    await _save();
    return ReminderOutcome(ReminderChannel.notification, plan.length, calendarRefused: refused);
  }

  /// Supprime les rappels d'un lot (éclosion saisie, lot supprimé…).
  Future<void> cancelForLot(String lotCode, {bool notify = true}) async {
    final r = _byLot.remove(lotCode);
    if (r != null) {
      for (final id in r.calendarIds) {
        try {
          await backend.deleteCalendarEvent(id);
        } catch (_) {
          // Événement déjà supprimé à la main dans l'agenda.
        }
      }
      for (final id in r.notificationIds) {
        await backend.cancelNotification(id);
      }
    }
    if (notify) await _save();
  }

  /// Recrée les rappels de tous les lots sans résultat (après un changement
  /// d'heure ou de mode). Renvoie le nombre de lots concernés.
  Future<int> rescheduleAll(Iterable<IncubationLot> lots, ReminderPrefs prefs) async {
    var n = 0;
    for (final l in lots) {
      if (l.hasResult) {
        await cancelForLot(l.code, notify: false);
        continue;
      }
      final o = await scheduleForLot(l, prefs);
      if (o.count > 0) n++;
    }
    await _save();
    return n;
  }

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode({for (final e in _byLot.entries) e.key: e.value.toJson()}));
    notifyListeners();
  }
}
