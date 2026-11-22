import 'format.dart';

/// Suivi santé et vaccination d'un lot de sujets.
/// Nafa fournit la structure de suivi : les produits, dates et doses sont
/// saisis par le producteur ou son vétérinaire. Aucune prescription n'est
/// proposée par l'application.
enum HealthKind {
  vaccination('Vaccination'),
  traitement('Traitement'),
  vermifuge('Déparasitage'),
  visite('Visite vétérinaire'),
  autre('Autre soin');

  const HealthKind(this.label);
  final String label;
}

enum HealthStatus {
  aVenir('À venir'),
  aujourdhui('Aujourd’hui'),
  enRetard('En retard'),
  realise('Réalisé');

  const HealthStatus(this.label);
  final String label;
}

class HealthRecord {
  HealthRecord({
    required this.id,
    required this.lotCode,
    required this.kind,
    required this.title,
    required this.plannedDate,
    this.doneDate,
    this.product = '',
    this.dosage = '',
    this.responsible = '',
    this.observation = '',
  }) {
    if (title.trim().isEmpty) throw ArgumentError('Indiquez le nom du vaccin ou du soin.');
    if (lotCode.trim().isEmpty) throw ArgumentError('Choisissez le lot concerné.');
  }

  final String id;
  final String lotCode;
  final HealthKind kind;
  final String title;
  final DateTime plannedDate;
  DateTime? doneDate;
  String product;
  String dosage;
  String responsible;
  String observation;

  HealthStatus statusAt(DateTime today) {
    if (doneDate != null) return HealthStatus.realise;
    final t = DateTime(today.year, today.month, today.day);
    final p = DateTime(plannedDate.year, plannedDate.month, plannedDate.day);
    if (p.isBefore(t)) return HealthStatus.enRetard;
    if (p == t) return HealthStatus.aujourdhui;
    return HealthStatus.aVenir;
  }

  /// Jours de retard (0 si à jour).
  int lateDays(DateTime today) =>
      statusAt(today) == HealthStatus.enRetard ? ageInDays(plannedDate, today) : 0;

  void markDone(DateTime date, {String? product, String? responsible}) {
    doneDate = DateTime(date.year, date.month, date.day);
    if (product != null && product.isNotEmpty) this.product = product;
    if (responsible != null && responsible.isNotEmpty) this.responsible = responsible;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'lotCode': lotCode,
        'kind': kind.name,
        'title': title,
        'plannedDate': _d(plannedDate),
        'doneDate': doneDate == null ? null : _d(doneDate!),
        'product': product,
        'dosage': dosage,
        'responsible': responsible,
        'observation': observation,
      };

  factory HealthRecord.fromJson(Map<String, Object?> j) => HealthRecord(
        id: j['id']! as String,
        lotCode: j['lotCode']! as String,
        kind: HealthKind.values.byName(j['kind']! as String),
        title: j['title']! as String,
        plannedDate: DateTime.parse(j['plannedDate']! as String),
        doneDate: j['doneDate'] == null ? null : DateTime.parse(j['doneDate']! as String),
        product: (j['product'] as String?) ?? '',
        dosage: (j['dosage'] as String?) ?? '',
        responsible: (j['responsible'] as String?) ?? '',
        observation: (j['observation'] as String?) ?? '',
      );
}

String _d(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
