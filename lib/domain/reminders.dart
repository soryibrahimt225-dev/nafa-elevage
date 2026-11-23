import 'format.dart';
import 'lots.dart';

/// Réglages des rappels (Paramètres > Rappels).
class ReminderPrefs {
  const ReminderPrefs({this.enabled = true, this.useCalendar = true, this.hour = 7, this.dayBefore = false});

  /// Rappels activés.
  final bool enabled;

  /// Ajouter les rappels à l'agenda du téléphone (sinon notification seule).
  final bool useCalendar;

  /// Heure du rappel (0 à 23).
  final int hour;

  /// Rappel la veille (sinon le jour même).
  final bool dayBefore;

  ReminderPrefs copyWith({bool? enabled, bool? useCalendar, int? hour, bool? dayBefore}) => ReminderPrefs(
        enabled: enabled ?? this.enabled,
        useCalendar: useCalendar ?? this.useCalendar,
        hour: hour ?? this.hour,
        dayBefore: dayBefore ?? this.dayBefore,
      );

  Map<String, Object?> toJson() =>
      {'enabled': enabled, 'useCalendar': useCalendar, 'hour': hour, 'dayBefore': dayBefore};

  factory ReminderPrefs.fromJson(Map<String, Object?> j) => ReminderPrefs(
        enabled: (j['enabled'] as bool?) ?? true,
        useCalendar: (j['useCalendar'] as bool?) ?? true,
        hour: (j['hour'] as int?) ?? 7,
        dayBefore: (j['dayBefore'] as bool?) ?? false,
      );
}

/// Rappel prévu pour un lot de couvaison.
class PlannedReminder {
  const PlannedReminder({
    required this.lotCode,
    required this.isHatch,
    required this.eventDate,
    required this.alertAt,
    required this.title,
    required this.body,
  });

  final String lotCode;
  final bool isHatch;

  /// Jour de l'étape (descente ou éclosion), à l'heure choisie.
  final DateTime eventDate;

  /// Moment de l'alerte (jour même ou veille, à l'heure choisie).
  final DateTime alertAt;
  final String title;
  final String body;

  /// Identifiant stable de notification (même lot + même étape = même id).
  int get notificationId => stableId('$lotCode-${isHatch ? 'eclosion' : 'descente'}');
}

/// Hachage FNV-1a 31 bits : stable d'un lancement à l'autre.
int stableId(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// Rappels de descente et d'éclosion d'un lot. Aucun rappel pour un lot dont
/// l'éclosion est saisie, ni pour une alerte déjà passée.
List<PlannedReminder> planReminders(IncubationLot lot, ReminderPrefs prefs, DateTime now) {
  if (!prefs.enabled || lot.hasResult) return const [];
  final s = lot.schedule;
  final out = <PlannedReminder>[];
  for (final (isHatch, day) in [(false, s.descenteDate), (true, s.hatchDate)]) {
    final event = DateTime(day.year, day.month, day.day, prefs.hour);
    final alert = prefs.dayBefore ? DateTime(day.year, day.month, day.day - 1, prefs.hour) : event;
    if (!alert.isAfter(now)) continue;
    final dayNumber = isHatch ? s.incubationDays : s.descenteDay;
    out.add(PlannedReminder(
      lotCode: lot.code,
      isHatch: isHatch,
      eventDate: event,
      alertAt: alert,
      title: isHatch ? 'Éclosion prévue · ${lot.code}' : 'Descendre les œufs · ${lot.code}',
      body: '${prefs.dayBefore ? 'Demain' : 'Aujourd’hui'} (${formatDate(day)}) : '
          '${isHatch ? 'éclosion prévue' : 'arrêt du retournement et descente'} — '
          '${formatInt(lot.eggsSet)} œufs ${lot.speciesLabel}, jour $dayNumber.',
    ));
  }
  return out;
}
