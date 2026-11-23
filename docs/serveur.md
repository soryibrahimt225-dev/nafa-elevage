# Serveur de synchronisation Nafa Élevage (PostgreSQL)

Le serveur (`server/`, écrit en Dart) gère :

- les **comptes** : inscription et connexion par numéro de téléphone et mot de passe (mot de passe chiffré avec bcrypt, jamais stocké en clair) ;
- les **fermes** et leurs **membres**, chacun avec un rôle ;
- les **données** de chaque ferme, envoyées et reçues par les téléphones (« Synchroniser »).

Les téléphones ne se connectent jamais directement à PostgreSQL : ils passent par ce serveur, qui vérifie l'identité et les droits.

## Droits par rôle (appliqués par le serveur)

Tous les membres peuvent **lire** toutes les données de la ferme.

| Rôle | Peut modifier |
|---|---|
| Propriétaire | tout ; gère les membres et tous les rôles |
| Gestionnaire | tout ; ajoute des membres (sauf propriétaire ou gestionnaire) |
| Employé de terrain | lots (mortalité, sorties), œufs, aliment, pesées |
| Technicien | lots, œufs, aliment, pesées, santé |
| Vétérinaire | santé et vaccination |
| Comptable | ventes et dépenses |

Une modification non autorisée est refusée par le serveur et annulée sur le téléphone, avec un message.

## Installation (serveur Linux, par exemple un VPS)

1. Installer PostgreSQL (version 14 ou plus récente) et Dart (version 3.8 ou plus récente).
2. Créer la base :

   ```bash
   sudo -u postgres createuser --pwprompt nafa
   ```

   ```bash
   sudo -u postgres createdb --owner nafa nafa
   ```

3. Lancer le serveur (les tables sont créées automatiquement au premier démarrage) :

   ```bash
   cd server && dart pub get && dart compile exe bin/server.dart -o nafa-server
   ```

   ```bash
   DATABASE_URL='postgresql://nafa:MOT_DE_PASSE@localhost:5432/nafa?sslmode=disable' PORT=8080 ./nafa-server
   ```

4. Mettre un **proxy HTTPS** devant (obligatoire : les mots de passe passent par le réseau). Exemple avec Caddy, qui obtient le certificat tout seul :

   ```
   nafa.exemple.ml {
       reverse_proxy localhost:8080
   }
   ```

5. Dans l'application : Paramètres › Compte et synchronisation › Serveur : `https://nafa.exemple.ml`.

Vérification : `https://nafa.exemple.ml/sante` répond `{"ok":true}`.

## Sauvegarde de la base

```bash
pg_dump --format=custom --file=nafa-$(date +%F).dump nafa
```

## Fonctionnement de la synchronisation

- On travaille toujours sur les données du téléphone, même sans connexion.
- « Synchroniser » reçoit d'abord les changements des autres téléphones, puis envoie les siens.
- Si deux téléphones ont modifié la même donnée, le serveur refuse le second envoi ; le téléphone **fusionne** (les ventes, lots, soins… ajoutés de chaque côté sont tous gardés, une suppression est respectée) puis renvoie.
- Les rappels d'agenda ne sont pas synchronisés (propres à chaque téléphone).

## Tests

```bash
cd server && TEST_DATABASE_URL='postgresql://postgres@localhost:5433/nafa_test?sslmode=disable' dart test -j 1
```

Test de bout en bout (application + serveur lancé sur le port 8090, base vide) :

```bash
SYNC_TEST_URL=http://localhost:8090 flutter test test/sync_e2e_test.dart
```

## Limites actuelles

- Pas de limitation du nombre d'essais de connexion (à ajouter avant une ouverture large, ou à faire par le proxy).
- Pas de réinitialisation du mot de passe par SMS : le propriétaire peut retirer puis réajouter un membre qui recrée son compte avec un autre numéro.
- Synchronisation manuelle (bouton), pas encore automatique.
