/// Schéma PostgreSQL de Nafa Élevage (créé au démarrage s'il n'existe pas).
const schemaSql = r'''
CREATE TABLE IF NOT EXISTS users (
  id            BIGSERIAL PRIMARY KEY,
  phone         TEXT NOT NULL UNIQUE,
  name          TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS farms (
  id           BIGSERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  location     TEXT NOT NULL DEFAULT '',
  data_version BIGINT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS memberships (
  farm_id BIGINT NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role    TEXT NOT NULL CHECK (role IN ('proprietaire','gestionnaire','employe','technicien','veterinaire','comptable')),
  PRIMARY KEY (farm_id, user_id)
);

-- Données de la ferme : une ligne par jeu de données (lots, ventes…),
-- avec un numéro de version croissant par ferme pour la synchronisation.
CREATE TABLE IF NOT EXISTS farm_data (
  farm_id    BIGINT NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  key        TEXT NOT NULL,
  value      TEXT NOT NULL,
  version    BIGINT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
  PRIMARY KEY (farm_id, key)
);
CREATE INDEX IF NOT EXISTS farm_data_version ON farm_data (farm_id, version);
''';
