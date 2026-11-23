/// Rôles prévus pour les utilisateurs de la ferme (dossier, section 4).
/// Les droits seront appliqués avec la synchronisation multi-appareils ;
/// pour l'instant, la liste sert à savoir qui travaille sur l'exploitation.
enum UserRole {
  proprietaire('Propriétaire', 'Tout voir, tout saisir, tout valider'),
  gestionnaire('Gestionnaire', 'Saisir et valider les opérations'),
  employe('Employé de terrain', 'Saisir la journée : mortalité, œufs, aliment'),
  technicien('Technicien', 'Suivre les lots, l’alimentation et la santé'),
  veterinaire('Vétérinaire', 'Suivre et valider la santé et la vaccination'),
  comptable('Comptable', 'Consulter et saisir ventes et dépenses');

  const UserRole(this.label, this.rights);
  final String label;
  final String rights;
}

class FarmUser {
  FarmUser(this.name, this.role) {
    if (name.trim().isEmpty) throw ArgumentError('Indiquez le nom de la personne.');
  }
  final String name;
  final UserRole role;

  Map<String, Object?> toJson() => {'name': name, 'role': role.name};
  factory FarmUser.fromJson(Map<String, Object?> j) =>
      FarmUser(j['name']! as String, UserRole.values.byName(j['role']! as String));
}

/// Fiche de l'exploitation. La devise est le franc CFA (FCFA) : tous les
/// montants de l'application sont en FCFA.
class FarmProfile {
  FarmProfile({this.name = '', this.location = '', List<FarmUser>? users}) : users = users ?? [];
  final String name;
  final String location;
  final List<FarmUser> users;

  static const currency = 'FCFA';

  /// Nom affiché (« Ma ferme » si rien n'est saisi).
  String get displayName => name.trim().isEmpty ? 'Ma ferme' : name.trim();

  Map<String, Object?> toJson() =>
      {'name': name, 'location': location, 'users': [for (final u in users) u.toJson()]};

  factory FarmProfile.fromJson(Map<String, Object?> j) => FarmProfile(
        name: (j['name'] as String?) ?? '',
        location: (j['location'] as String?) ?? '',
        users: [for (final u in (j['users'] as List? ?? const [])) FarmUser.fromJson((u as Map).cast())],
      );
}
