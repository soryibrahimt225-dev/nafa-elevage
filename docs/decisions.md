# Journal des décisions

Chaque décision indique sa source : **client** (validée par le client), ou **proposition** (appliquée par défaut en attendant la validation du client, voir `audit-phase1-3.md`).

| Date | Sujet | Décision | Source |
|---|---|---|---|
| 22/11/2026 | Dépôt et technologie | Dépôt dédié `nafa-elevage`, application Flutter (web et mobile) | client |
| 22/11/2026 | Fichier Excel | Référence métier ; import de l'onglet « Lots » proposé comme fonction pratique | client |
| 22/11/2026 | Jour 0 de couvaison | Le jour de mise en couveuse est le jour 0 ; éclosion = entrée + durée (comme le classeur) | proposition (audit n° 1) |
| 22/11/2026 | Jour de descente | Paramètre par espèce, modifiable : Goliath 16, poule 18, pintade, canard et dindon 25, canard de Barbarie 31 | proposition (audit n° 2 et 3) |
| 22/11/2026 | Reste à recouvrer | Toujours recalculé ; remise saisie à part ; encaissement supérieur au dû refusé | proposition (audit n° 4) |
| 22/11/2026 | Taux d'éclosion mensuel | Calculé sur les seuls lots avec résultat saisi | proposition (audit n° 6) |
| 22/11/2026 | Catégories de dépenses | Liste fermée (Aliment, Transport, Main-d'œuvre…) | proposition (audit n° 12) |
| 22/11/2026 | Couvaison et œufs fertiles | Deux produits distincts : service de couvaison, œuf fertile vendu | proposition (audit n° 13) |
| 22/11/2026 | Dépenses générales | Gardées à part, jamais réparties automatiquement entre les lots | dossier de recherche |
| 23/11/2026 | Rappels | Agenda natif si autorisé, sinon notification locale ; heure approximative (pas d'autorisation « alarmes exactes ») | master prompt + proposition |
| 23/11/2026 | Vaccination des poussins gardés | Santé et vaccination ajoutées pour les **bandes de poussins gardés** de la couveuse, accessibles depuis « Poussins gardés » et le tableau de bord. Les **lots d'œufs** et le menu de la couveuse restent sans vaccination. | client |
| 23/11/2026 | Ordre de l'assistant | La production est demandée en premier (master prompt), puis les étapes du dossier : ferme, race, premier lot, aliment, prix, utilisateurs. Chaque étape après la production peut être passée. | master prompt + dossier |
| 23/11/2026 | Devise | Franc CFA (FCFA) uniquement, affiché dans l'assistant | proposition |
| 23/11/2026 | Utilisateurs et rôles | Liste des personnes et de leur rôle enregistrée dès maintenant ; droits appliqués avec la synchronisation | proposition |
| 23/11/2026 | Bouton principal | Le bouton s'appelle **« Saisir »** (et non « Saisir aujourd'hui », jugé trop générique). Il se trouve sur le tableau de bord et propose les saisies utiles à la production choisie. | client |
| 23/11/2026 | Indice de consommation | IC = aliment distribué entre la première et la dernière pesée ÷ (gain de poids moyen × sujets présents à la dernière pesée). Pour compter depuis le démarrage, une pesée est saisie le jour du démarrage. Aucune valeur de référence de souche n'est affichée. | proposition |
| 23/11/2026 | Sauvegarde | Un fichier JSON contient toutes les données de l'appareil, sauf les rappels d'agenda (propres à chaque téléphone, à recréer après restauration). La restauration remplace tout après confirmation ; les données d'avant sont gardées pour annuler ; un fichier abîmé est refusé sans rien changer. | client + proposition |
| 23/11/2026 | Serveur | Serveur propre en Dart avec **PostgreSQL** (demande du client), comptes par numéro de téléphone et mot de passe ; les téléphones passent par l'API, jamais directement par la base. | client |
| 23/11/2026 | Droits par rôle | Appliqués par le serveur (tableau dans docs/serveur.md) ; une modification non autorisée est annulée sur le téléphone. | proposition |
| 23/11/2026 | Conflits | Fusion enregistrement par enregistrement (ajouts gardés des deux côtés, suppressions respectées, la modification du téléphone l'emporte sur le même champ). | proposition |
| 24/11/2026 | Vente des œufs | Les œufs de table se vendent **à l'alvéole** ; nombre d'œufs par alvéole réglable (30 par défaut) ; les rapports comptent les œufs et les alvéoles. | client |
| 24/11/2026 | Prix des sujets | **Un prix par type de sujet** (races améliorées : 2 mois engraissement, 6 mois, réforme ; pondeuses : poulette, réforme ; poussins : 1 jour, 2 semaines, 1 mois). Types modifiables ; à la vente, on choisit le type et son prix est proposé. | client |
| 24/11/2026 | Prix des aliments | **Un prix par aliment** (démarrage, croissance, finition, pondeuse…) dans l'assistant et sur chaque fiche d'aliment ; proposé à chaque achat. | client |
| 24/11/2026 | Races améliorées : objectifs | Un même lot mène **ensemble** l'engraissement, la ponte et la reproduction (couvaison) : les trois objectifs sont cochés par défaut, modifiables à tout moment sans perdre l'historique. Répartition facultative des sujets entre objectifs (ex. 60 / 30 / 10). « Couvaison et conversion » est activée d'office pour les races améliorées. | client |
