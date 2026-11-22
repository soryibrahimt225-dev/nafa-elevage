/// Calendrier de couvaison.
///
/// Convention (reprise du classeur Gestion-couvoir-2026.xlsx) : le jour de
/// mise en couveuse est le jour 0. Éclosion prévue = date d'entrée + durée.
/// Descente (arrêt du retournement) = date d'entrée + jour de descente.
/// Point « À valider » n° 1 et 2 de l'audit : valeurs configurables.
class SpeciesProfile {
  const SpeciesProfile({
    required this.id,
    required this.label,
    required this.incubationDays,
    required this.descenteDay,
  });

  final String id;
  final String label;
  final int incubationDays;
  final int descenteDay;

  SpeciesProfile copyWith({int? incubationDays, int? descenteDay}) =>
      SpeciesProfile(
        id: id,
        label: label,
        incubationDays: incubationDays ?? this.incubationDays,
        descenteDay: descenteDay ?? this.descenteDay,
      );
}

/// Valeurs par défaut, modifiables dans Paramètres.
/// Sources : master prompt (Goliath jour 16), NC State / Utah State Extension
/// (poule 18, canard / dindon / pintade 25, canard de Barbarie 35 j / 31).
const defaultSpeciesProfiles = <SpeciesProfile>[
  SpeciesProfile(id: 'goliath', label: 'Goliath', incubationDays: 21, descenteDay: 16),
  SpeciesProfile(id: 'poule', label: 'Poulet local ou chair', incubationDays: 21, descenteDay: 18),
  SpeciesProfile(id: 'pintade', label: 'Pintade', incubationDays: 28, descenteDay: 25),
  SpeciesProfile(id: 'canard', label: 'Canard commun', incubationDays: 28, descenteDay: 25),
  SpeciesProfile(id: 'barbarie', label: 'Canard de Barbarie', incubationDays: 35, descenteDay: 31),
  SpeciesProfile(id: 'dindon', label: 'Dindon', incubationDays: 28, descenteDay: 25),
];

enum IncubationStatus {
  enIncubation('En incubation'),
  descenteFaite('Œufs descendus'),
  eclosionImminente('Éclosion imminente'),
  aVerifier('À vérifier : éclosion passée'),
  termine('Terminé');

  const IncubationStatus(this.label);
  final String label;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class IncubationSchedule {
  IncubationSchedule({
    required DateTime entryDate,
    required this.incubationDays,
    required this.descenteDay,
  }) : entryDate = _day(entryDate) {
    if (incubationDays <= 0) {
      throw ArgumentError('La durée d’incubation doit être positive.');
    }
    if (descenteDay <= 0 || descenteDay >= incubationDays) {
      throw ArgumentError(
          'Le jour de descente doit être compris entre 1 et ${incubationDays - 1}.');
    }
  }

  factory IncubationSchedule.forProfile(DateTime entryDate, SpeciesProfile p) =>
      IncubationSchedule(
          entryDate: entryDate,
          incubationDays: p.incubationDays,
          descenteDay: p.descenteDay);

  final DateTime entryDate;
  final int incubationDays;
  final int descenteDay;

  DateTime get descenteDate => _addDays(entryDate, descenteDay);
  DateTime get hatchDate => _addDays(entryDate, incubationDays);

  /// Jour d'incubation à une date donnée (0 = jour de mise en couveuse).
  int dayAt(DateTime today) => _day(today).difference(entryDate).inDays;

  /// Statut, même logique que le classeur (marge de 2 jours après l'éclosion
  /// prévue avant « À vérifier »), mais un résultat saisi termine le lot.
  IncubationStatus statusAt(DateTime today, {bool hatchRecorded = false}) {
    if (hatchRecorded) return IncubationStatus.termine;
    final t = _day(today);
    if (t.isAfter(_addDays(hatchDate, 2))) return IncubationStatus.aVerifier;
    if (!t.isBefore(_addDays(hatchDate, -1))) {
      return IncubationStatus.eclosionImminente;
    }
    if (!t.isBefore(descenteDate)) return IncubationStatus.descenteFaite;
    return IncubationStatus.enIncubation;
  }

  // Ajout calendaire (évite les décalages liés aux changements d'heure).
  static DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
}

/// Taux d'éclosion d'un lot : éclos / œufs mis. `null` si rien n'est saisi.
double? hatchRate({required int eggsSet, int? hatched}) {
  if (hatched == null || eggsSet <= 0) return null;
  if (hatched < 0 || hatched > eggsSet) {
    throw ArgumentError('Le nombre d’éclos doit être compris entre 0 et $eggsSet.');
  }
  return hatched / eggsSet;
}
