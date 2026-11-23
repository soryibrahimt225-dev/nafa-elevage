import 'format.dart';
import 'incubation.dart';
import 'production.dart';

/// Types de sortie d'un lot de sujets. L'effectif actuel se calcule toujours :
/// effectif initial − toutes les sorties (jamais saisi à la main).
enum MovementType {
  mortalite('Mortalité'),
  vente('Vente'),
  reforme('Réforme'),
  autre('Autre sortie');

  const MovementType(this.label);
  final String label;
}

class Movement {
  const Movement({required this.date, required this.type, required this.count, this.note = '', this.ref});

  final DateTime date;
  final MovementType type;
  final int count;
  final String note;

  /// Opération liée (ex. identifiant de la vente qui a créé cette sortie).
  final String? ref;

  Map<String, Object?> toJson() =>
      {'date': _d(date), 'type': type.name, 'count': count, 'note': note, if (ref != null) 'ref': ref};

  factory Movement.fromJson(Map<String, Object?> j) => Movement(
        date: DateTime.parse(j['date']! as String),
        type: MovementType.values.byName(j['type']! as String),
        count: j['count']! as int,
        note: (j['note'] as String?) ?? '',
        ref: j['ref'] as String?,
      );
}

/// Objectif d'un lot de races améliorées (configurable, modifiable sans perdre
/// l'historique).
enum LotObjective {
  engraissement('Engraissement et vente'),
  ponte('Conservation pour la ponte'),
  reproduction('Reproduction et couvaison');

  const LotObjective(this.label);
  final String label;
}

enum LotStatus {
  enCours('En cours'),
  termine('Terminé');

  const LotStatus(this.label);
  final String label;
}

/// Lot de sujets (poulets de chair, races améliorées, pondeuses).
class AnimalLot {
  AnimalLot({
    required this.id,
    required this.code,
    required this.production,
    required this.breed,
    required this.startDate,
    required this.initialCount,
    this.objective,
    List<Movement>? movements,
    this.closed = false,
    this.notes = '',
  }) : movements = movements ?? [] {
    if (production == ProductionType.couveuse) {
      throw ArgumentError('Un lot de couveuse est un lot d’œufs, pas un lot de sujets.');
    }
    if (initialCount <= 0) throw ArgumentError('L’effectif initial doit être supérieur à 0.');
    if (breed.trim().isEmpty) throw ArgumentError('Indiquez la race ou la souche.');
  }

  final String id;
  final String code;
  final ProductionType production;
  final String breed;
  final DateTime startDate;
  final int initialCount;
  LotObjective? objective;
  final List<Movement> movements;
  bool closed;
  String notes;

  int countOf(MovementType t) =>
      movements.where((m) => m.type == t).fold(0, (s, m) => s + m.count);
  int get dead => countOf(MovementType.mortalite);
  int get exits => movements.fold(0, (s, m) => s + m.count);
  int get current => initialCount - exits;

  /// Effectif à une date (sorties enregistrées jusqu'à ce jour compris).
  int countAt(DateTime date) {
    final d = _day(date);
    return initialCount -
        movements.where((m) => !_day(m.date).isAfter(d)).fold(0, (s, m) => s + m.count);
  }

  /// Mortalité cumulée / effectif initial.
  double get mortalityRate => dead / initialCount;

  int ageAt(DateTime today) => ageInDays(startDate, today);

  LotStatus get status => closed || current == 0 ? LotStatus.termine : LotStatus.enCours;

  /// Ajoute une sortie après contrôle de cohérence.
  void addMovement(Movement m) {
    if (m.count <= 0) throw ArgumentError('Le nombre doit être supérieur à 0.');
    if (m.count > current) {
      throw ArgumentError('Impossible : il ne reste que ${formatInt(current)} sujets dans le lot.');
    }
    if (_day(m.date).isBefore(_day(startDate))) {
      throw ArgumentError('La date est antérieure à la création du lot.');
    }
    movements.add(m);
    movements.sort((a, b) => a.date.compareTo(b.date));
  }

  /// Retire les sorties créées par une opération supprimée (ex. une vente).
  bool removeMovementsFor(String ref) {
    final before = movements.length;
    movements.removeWhere((m) => m.ref == ref);
    return movements.length != before;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'production': production.name,
        'breed': breed,
        'startDate': _d(startDate),
        'initialCount': initialCount,
        'objective': objective?.name,
        'movements': [for (final m in movements) m.toJson()],
        'closed': closed,
        'notes': notes,
      };

  factory AnimalLot.fromJson(Map<String, Object?> j) => AnimalLot(
        id: j['id']! as String,
        code: j['code']! as String,
        production: ProductionType.values.byName(j['production']! as String),
        breed: j['breed']! as String,
        startDate: DateTime.parse(j['startDate']! as String),
        initialCount: j['initialCount']! as int,
        objective: j['objective'] == null ? null : LotObjective.values.byName(j['objective']! as String),
        movements: [
          for (final m in (j['movements'] as List? ?? const []))
            Movement.fromJson((m as Map).cast<String, Object?>())
        ],
        closed: (j['closed'] as bool?) ?? false,
        notes: (j['notes'] as String?) ?? '',
      );
}

/// Propriétaire d'un lot d'œufs. Les préfixes BUR et CLI reprennent ceux
/// du classeur, pour garder les mêmes codes.
enum OwnerType {
  producteur('Producteur', 'BUR'),
  client('Client', 'CLI');

  const OwnerType(this.label, this.prefix);
  final String label;
  final String prefix;
}

/// Lot de couvaison.
class IncubationLot {
  IncubationLot({
    required this.id,
    required this.code,
    required this.ownerType,
    required this.ownerName,
    required this.speciesLabel,
    required this.entryDate,
    required this.eggsSet,
    required this.incubationDays,
    required this.descenteDay,
    int? hatched,
    int? chickDeaths,
    this.observations = '',
  }) {
    if (eggsSet <= 0) throw ArgumentError('Le nombre d’œufs doit être supérieur à 0.');
    // Contrôle des dates par le calendrier lui-même.
    IncubationSchedule(entryDate: entryDate, incubationDays: incubationDays, descenteDay: descenteDay);
    recordHatch(hatched: hatched, chickDeaths: chickDeaths);
  }

  final String id;
  final String code;
  final OwnerType ownerType;
  final String ownerName;
  final String speciesLabel;
  final DateTime entryDate;
  final int eggsSet;
  final int incubationDays;
  final int descenteDay;
  int? _hatched;
  int? _chickDeaths;
  String observations;

  int? get hatched => _hatched;
  int? get chickDeaths => _chickDeaths;

  /// Saisie du résultat d'éclosion, avec contrôles (audit, point 8).
  void recordHatch({int? hatched, int? chickDeaths}) {
    if (hatched != null && (hatched < 0 || hatched > eggsSet)) {
      throw ArgumentError('Le nombre d’éclos doit être compris entre 0 et $eggsSet.');
    }
    if (chickDeaths != null) {
      if (hatched == null) throw ArgumentError('Saisissez d’abord le nombre d’éclos.');
      if (chickDeaths < 0 || chickDeaths > hatched) {
        throw ArgumentError('La mortalité doit être comprise entre 0 et $hatched.');
      }
    }
    _hatched = hatched;
    _chickDeaths = chickDeaths;
  }

  IncubationSchedule get schedule =>
      IncubationSchedule(entryDate: entryDate, incubationDays: incubationDays, descenteDay: descenteDay);

  bool get hasResult => _hatched != null;
  int? get unhatched => _hatched == null ? null : eggsSet - _hatched!;
  int? get alive => _hatched == null ? null : _hatched! - (_chickDeaths ?? 0);
  double? get hatchRate => _hatched == null ? null : _hatched! / eggsSet;

  /// Contrôle : toute la mortalité saisie = tous les éclos (à confirmer).
  bool get suspiciousMortality => _hatched != null && _hatched! > 0 && _chickDeaths == _hatched;

  IncubationStatus statusAt(DateTime today) => schedule.statusAt(today, hatchRecorded: hasResult);

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'ownerType': ownerType.name,
        'ownerName': ownerName,
        'speciesLabel': speciesLabel,
        'entryDate': _d(entryDate),
        'eggsSet': eggsSet,
        'incubationDays': incubationDays,
        'descenteDay': descenteDay,
        'hatched': _hatched,
        'chickDeaths': _chickDeaths,
        'observations': observations,
      };

  factory IncubationLot.fromJson(Map<String, Object?> j) => IncubationLot(
        id: j['id']! as String,
        code: j['code']! as String,
        ownerType: OwnerType.values.byName(j['ownerType']! as String),
        ownerName: j['ownerName']! as String,
        speciesLabel: j['speciesLabel']! as String,
        entryDate: DateTime.parse(j['entryDate']! as String),
        eggsSet: j['eggsSet']! as int,
        incubationDays: j['incubationDays']! as int,
        descenteDay: j['descenteDay']! as int,
        hatched: j['hatched'] as int?,
        chickDeaths: j['chickDeaths'] as int?,
        observations: (j['observations'] as String?) ?? '',
      );
}

/// Préfixe des codes de lots de sujets.
String animalPrefix(ProductionType p) {
  switch (p) {
    case ProductionType.chair:
      return 'CHA';
    case ProductionType.ameliorees:
      return 'AME';
    case ProductionType.pondeuses:
      return 'PON';
    case ProductionType.couveuse:
      throw ArgumentError('La couveuse utilise les préfixes BUR et CLI.');
  }
}

/// Code suivant : PREFIXE-AA-NNN, numéroté par préfixe et par année
/// (ex. BUR-26-032). Prend le plus grand numéro existant + 1, pour ne jamais
/// réutiliser un code même si un lot a été supprimé ou importé.
String nextLotCode(String prefix, DateTime date, Iterable<String> existingCodes) {
  final yy = (date.year % 100).toString().padLeft(2, '0');
  final head = '$prefix-$yy-';
  var max = 0;
  for (final c in existingCodes) {
    if (!c.startsWith(head)) continue;
    final n = int.tryParse(c.substring(head.length));
    if (n != null && n > max) max = n;
  }
  return '$head${(max + 1).toString().padLeft(3, '0')}';
}

String _d(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Échéance d'un lot de couvaison (descente ou éclosion).
class IncubationEvent {
  const IncubationEvent(this.lot, this.date, this.isHatch);
  final IncubationLot lot;
  final DateTime date;
  final bool isHatch;
  String get label => isHatch ? 'Éclosion prévue' : 'Descente des œufs';
}

/// Échéances des [days] prochains jours (aujourd'hui compris), pour les lots
/// sans résultat saisi. Une éclosion saisie annule les rappels du lot.
List<IncubationEvent> upcomingEvents(Iterable<IncubationLot> lots, DateTime today, {int days = 10}) {
  final start = _day(today);
  final end = DateTime(start.year, start.month, start.day + days);
  bool inRange(DateTime d) => !d.isBefore(start) && !d.isAfter(end);
  final events = <IncubationEvent>[
    for (final l in lots)
      if (!l.hasResult) ...[
        if (inRange(l.schedule.descenteDate)) IncubationEvent(l, l.schedule.descenteDate, false),
        if (inRange(l.schedule.hatchDate)) IncubationEvent(l, l.schedule.hatchDate, true),
      ],
  ];
  events.sort((a, b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.lot.code.compareTo(b.lot.code);
  });
  return events;
}

/// Synthèse des lots de couvaison (même règles que le classeur : le taux
/// d'éclosion ne compte que les lots dont le résultat est saisi).
class IncubationSummary {
  IncubationSummary(Iterable<IncubationLot> all, DateTime today) {
    for (final l in all) {
      lots++;
      eggsSet += l.eggsSet;
      final s = l.statusAt(today);
      if (l.hasResult) {
        eggsWithResult += l.eggsSet;
        hatched += l.hatched!;
        chickDeaths += l.chickDeaths ?? 0;
        alive += l.alive!;
        if (l.suspiciousMortality) toCheck++;
      } else if (s == IncubationStatus.aVerifier) {
        toCheck++;
        missingResult++;
      } else {
        running++;
        eggsRunning += l.eggsSet;
      }
    }
  }

  int lots = 0, eggsSet = 0, eggsWithResult = 0, hatched = 0, chickDeaths = 0, alive = 0;
  int running = 0, eggsRunning = 0, toCheck = 0, missingResult = 0;

  int get unhatched => eggsWithResult - hatched;
  double? get hatchRate => eggsWithResult == 0 ? null : hatched / eggsWithResult;
  double? get mortalityRate => hatched == 0 ? null : chickDeaths / hatched;
}

/// Ligne de la production mensuelle de la couveuse.
class MonthlyHatch {
  MonthlyHatch(this.month);
  final DateTime month;
  int lots = 0, eggsSet = 0, eggsWithResult = 0, hatched = 0, deaths = 0, alive = 0;

  int get unhatched => eggsWithResult - hatched;

  /// Taux calculé sur les seuls lots dont le résultat est saisi (audit, point 6).
  double? get hatchRate => eggsWithResult == 0 ? null : hatched / eggsWithResult;
  double? get mortalityRate => hatched == 0 ? null : deaths / hatched;

  void add(IncubationLot l) {
    lots++;
    eggsSet += l.eggsSet;
    if (l.hasResult) {
      eggsWithResult += l.eggsSet;
      hatched += l.hatched!;
      deaths += l.chickDeaths ?? 0;
      alive += l.alive!;
    }
  }
}

/// Production mensuelle, par mois d'éclosion prévue (règle du classeur),
/// tous les mois entre le premier et le dernier compris.
/// [owner] : filtre producteur ou client ; `null` = tous les lots.
List<MonthlyHatch> monthlyProduction(Iterable<IncubationLot> lots, {OwnerType? owner}) {
  final list = [for (final l in lots) if (owner == null || l.ownerType == owner) l];
  if (list.isEmpty) return const [];
  DateTime m(IncubationLot l) => DateTime(l.schedule.hatchDate.year, l.schedule.hatchDate.month);
  final months = list.map(m).toList()..sort();
  final rows = <MonthlyHatch>[];
  for (var d = months.first; !d.isAfter(months.last); d = DateTime(d.year, d.month + 1)) {
    rows.add(MonthlyHatch(d));
  }
  for (final l in list) {
    final key = m(l);
    rows.firstWhere((r) => r.month == key).add(l);
  }
  return rows;
}

/// Total d'un ensemble de lignes.
MonthlyHatch totalOf(Iterable<MonthlyHatch> rows) {
  final t = MonthlyHatch(DateTime(0));
  for (final r in rows) {
    t
      ..lots += r.lots
      ..eggsSet += r.eggsSet
      ..eggsWithResult += r.eggsWithResult
      ..hatched += r.hatched
      ..deaths += r.deaths
      ..alive += r.alive;
  }
  return t;
}
