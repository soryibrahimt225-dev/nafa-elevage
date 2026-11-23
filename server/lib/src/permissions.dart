/// Rôles et droits d'écriture par jeu de données. Tous les membres d'une
/// ferme peuvent lire toutes ses données.
const roles = ['proprietaire', 'gestionnaire', 'employe', 'technicien', 'veterinaire', 'comptable'];

/// Jeux de données synchronisés (clés de stockage de l'application).
const syncedKeys = {
  'nafa.production',
  'nafa.options',
  'nafa.farm.v1',
  'nafa.config.v1',
  'nafa.lots.v1',
  'nafa.finance.v1',
  'nafa.health.v1',
  'nafa.eggs.v1',
  'nafa.feed.v1',
  'nafa.weighings.v1',
};

const _fieldWork = {'nafa.lots.v1', 'nafa.eggs.v1', 'nafa.feed.v1', 'nafa.weighings.v1'};

const _writable = <String, Set<String>>{
  'proprietaire': syncedKeys,
  'gestionnaire': syncedKeys,
  // Employé de terrain : mortalité, œufs, aliment, pesées.
  'employe': _fieldWork,
  // Technicien : suivi des lots, de l'alimentation et de la santé.
  'technicien': {..._fieldWork, 'nafa.health.v1'},
  // Vétérinaire : santé et vaccination.
  'veterinaire': {'nafa.health.v1'},
  // Comptable : ventes et dépenses.
  'comptable': {'nafa.finance.v1'},
};

bool canWrite(String role, String key) => _writable[role]?.contains(key) ?? false;

/// Seuls le propriétaire et le gestionnaire gèrent les membres ; seul le
/// propriétaire peut nommer un autre propriétaire ou un gestionnaire.
bool canManageMembers(String role) => role == 'proprietaire' || role == 'gestionnaire';
bool canGrant(String actorRole, String newRole) =>
    actorRole == 'proprietaire' || (actorRole == 'gestionnaire' && newRole != 'proprietaire' && newRole != 'gestionnaire');
