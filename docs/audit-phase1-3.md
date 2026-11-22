# Nafa Élevage — Audit Phases 1 à 3

Date : 22 novembre 2026. Fichiers examinés : master prompt (.md et .docx, identiques), dossier de recherche (.docx), `Gestion-couvoir-2026.xlsx` (14 onglets, formules et valeurs en cache), 3 maquettes HTML, base d'application `04_Base_Application`, logo.

## 1. Synthèse (Phase 1)

### Exigences confirmées par le client (master prompt)
- Onboarding : « Quelle production voulez-vous gérer ? » avec 4 choix (chair, races améliorées, pondeuses, couveuse) ; seuls les modules utiles à la production choisie sont affichés ; d'autres modules peuvent être activés dans Paramètres.
- Vocabulaire : « sujet(s) », jamais « oiseau » ; démarrage, poulette, finition, pondeuse, ponte, maintien, réforme, lot, couvaison, éclosion.
- Montants toujours complets (« 588 256 FCFA »), jamais abrégés.
- Âge du lot calculé automatiquement en jours.
- Santé et vaccination pour chair, races améliorées et pondeuses, mais pas pour la couveuse. Aucune prescription vétérinaire inventée.
- Couveuse : lots avec propriétaire (producteur ou client), durées configurables, dates de descente et d'éclosion calculées automatiquement, production mensuelle.
- Agenda natif Android et iPhone (Flutter), avec notification locale si l'accès est refusé.
- Races améliorées : cycle configurable (sélection vers 4 mois, ponte vers 6 mois, contrôles à 12 et 24 mois). La réforme n'est jamais automatique.
- Comptabilité commune à tous les modules, opérations liées à une production, une race, un lot ou une activité de couveuse ; prix configurables.
- Logo validé : poule verte et or avec « Nafa ».

### Hypothèses / recommandations (dossier de recherche — à valider)
- Liste des races et souches (Ross 308, Cobb 500, ISA Brown…) : disponibilité au Mali non confirmée.
- Phases d'alimentation Ross et repère Goliath « démarrage jusqu'à environ 45 jours » : repères, pas des règles.
- Assistant de démarrage en 8 étapes et rôles utilisateurs : proposés, non validés.
- Répartition des dépenses générales entre les lots : règle non définie.

### Données issues du fichier Excel (réelles, couvoir Goliath)
- 39 lots (31 bureau, 8 clients), 2 466 œufs mis, 863 éclos, 804 poussins vivants. Taux d'éclosion : 58,1 % (calculé sur les lots dont l'éclosion a été saisie).
- 44 ventes pour un chiffre d'affaires de 588 256 FCFA ; 7 dépenses pour 89 500 FCFA.
- 2 bandes d'élevage (50 poussins gardés).
- Logique utile à reprendre : codes de lot automatiques `BUR-26-001` / `CLI-26-001`, catalogue de produits à code unique, statut calculé, contrôles de cohérence (onglet Synthèse), programme des sorties, comparatif bureau / client.

## 2. Recherches (Phase 2 — premier lot)

| Sujet | Source (consultée le 22/11/2026) | Information retenue | Confiance | Impact |
|---|---|---|---|---|
| Durées d'incubation et arrêt du retournement | [NC State Egg Temp Chart](https://poultry4hyouth.ces.ncsu.edu/wp-content/uploads/2020/03/Egg-Temp-Chart.pdf?fwd=no), [Utah State Extension](https://extension.usu.edu/poultry/research/hatching-and-caring-for-chicks.php), [Oklahoma State](https://extension.okstate.edu/fact-sheets/artificial-incubation) | Poule : 21 j (20 à 22), arrêt au jour 18. Canard commun : 28 j, arrêt au jour 25. **Canard de Barbarie : 35 à 37 j, arrêt au jour 31.** Dindon : 28 j, arrêt au jour 25. Pintade : 26 à 28 j, arrêt au jour 25. | Élevée (vulgarisation universitaire) | Profils d'espèce configurables ; il faut ajouter le canard de Barbarie |
| Agenda natif Flutter | [device_calendar_plus (pub.dev)](https://pub.dev/packages/device_calendar_plus), [device_calendar](https://pub.dev/documentation/device_calendar/latest/) | `device_calendar` n'est plus maintenu. `device_calendar_plus` est maintenu et utilise Calendar Provider (Android, version 24 minimum) et EventKit (iOS 13 minimum). Il faut les autorisations READ/WRITE_CALENDAR et les textes d'usage dans Info.plist. Aucun repli intégré : la notification locale (par exemple `flutter_local_notifications`) est à concevoir dans l'application. | Moyenne à élevée | Choix du plugin pour l'étape 10 |

Recherches restant à faire : calendriers de vaccination au Mali (à faire valider par un vétérinaire), alimentation Goliath, accessibilité pour les utilisateurs peu scolarisés (icônes, voix, bambara).

## 3. Liste « À valider » (Phase 3)

| # | Problème | Conséquence | Proposition | Décision attendue |
|---|---|---|---|---|
| 1 | **Convention du jour de mise en couveuse.** Dans l'Excel, l'éclosion tombe à la date d'entrée + 21 jours (le jour d'entrée compte comme jour 0). La base d'application calcule date d'entrée + 21 − 1 (le jour d'entrée compte comme jour 1). | Dates de l'agenda décalées d'un jour. Exemple : mise le 22/11 → éclosion le 13/12 dans l'Excel, le 12/12 dans le code de la base. | Suivre la règle de l'Excel : éclosion = entrée + durée, et afficher « Jour 0 = mise en couveuse ». | Confirmer la convention |
| 2 | **Jour de descente.** L'Excel applique « éclosion − 5 jours » à toutes les espèces (jour 16 pour la poule, jour 23 pour la pintade). Le master prompt indique Goliath au jour 16 mais poulet local / chair au jour 18. Les recherches donnent jour 18 pour la poule et jour 25 pour la pintade. | Rappels de descente faux pour la pintade et le canard si la règle « − 5 » est conservée. | Un paramètre « jour de descente » par espèce et par race. Valeurs par défaut : Goliath 16, poule 18, pintade 25, canard 25, dindon 25. | Valider les valeurs par défaut, en particulier la pintade |
| 3 | « Canard : environ 28 jours ». Le canard de Barbarie, courant en Afrique de l'Ouest, demande 35 à 37 jours. | Éclosion annoncée une semaine trop tôt. | Ajouter un profil « Canard de Barbarie » (35 jours, descente au jour 31). | Quelle(s) espèce(s) de canard ? |
| 4 | **Reste à recouvrer faux dans l'Excel.** Les valeurs en cache affichent −20 FCFA alors que chiffre d'affaires − encaissé = 588 256 − 570 476 = **17 780 FCFA**. Six ventes sont partielles (CARA 3 000, CHEICK 12 600, CLT MEC 1 200, ZIDANE 600, 2 × 200), mais elles affichent « Payé ». | Le tableau de bord sous-estime les créances. La maquette, elle, affiche 66 500 FCFA, un chiffre inventé. | L'application recalcule toujours les montants à partir des lignes. Les remises deviennent un champ explicite (« remise accordée ») pour ne pas être comptées comme des impayés. | Les écarts sont-ils des remises ou des impayés ? |
| 5 | Lots, colonne « Poussins vendus » : la formule additionne le **prix unitaire** (Ventes!H) au lieu de la quantité (Ventes!G). De plus, aucune vente n'est liée à un code lot. | Le restant théorique par lot est faux, ou toujours à zéro. | Dans l'application, une vente de poussins est obligatoirement liée à un lot de couvaison ou à une bande. | Lier les ventes historiques ? |
| 6 | La colonne « Œufs mis » de ProductionMensuelle inclut les lots sans éclosion saisie. Exemple pour juin : 366 œufs mis, mais 83 éclos et 162 non éclos (245 œufs seulement). | Un lecteur divise 83 / 366 et obtient 22,7 % au lieu de 33,9 %. La base d'application reproduit ce tableau. | Afficher deux colonnes, « Œufs mis » et « Œufs avec résultat », et calculer le taux sur la seconde. | Valider |
| 7 | 10 lots du bureau sont « À vérifier — éclosion passée » (éclosion jamais saisie), dont 2 lots clients. | Les taux et la production mensuelle sont incomplets. | Les importer avec ce statut et afficher une alerte. | Fournir les chiffres manquants si possible |
| 8 | BUR-26-020 : la mortalité saisie est de 36, soit tous les poussins éclos. Ce lot porte à lui seul le taux de mortalité d'octobre à 70,6 %. | Les indicateurs de mortalité sont faussés. | Contrôle de saisie : mortalité ≤ nombre d'éclos, avec confirmation si elle est égale. | Corriger la valeur réelle |
| 9 | Écarts entre l'onglet Lots et le suivi quotidien : BUR-26-024 (74 / 72), BUR-26-025 (75 / 74), **BUR-26-027 (77 / 64)**. | Deux sources différentes pour le même chiffre. | Une seule source dans l'application : les éclosions du jour s'additionnent pour donner le total du lot. | Quelle source fait foi ? |
| 10 | BUR-26-028 : éclosion enregistrée le 21/11 (jour 19) alors qu'elle était prévue le 23/11. Le lot est « Terminé », mais il figure encore dans les échéances du tableau de bord. | Éclosions précoces non gérées, échéances fantômes. | Une éclosion réelle saisie annule les rappels restants du lot. | — |
| 11 | Le stade des bandes d'élevage dans l'Excel (Démarrage ≤ 7 j, Croissance ≤ 28 j, Finition ≤ 56 j, « Prêt à vendre ») ne correspond ni au vocabulaire imposé (démarrage / poulette / finition) ni au repère Goliath (démarrage jusqu'à environ 45 jours). | Des stades erronés pour les sujets gardés en vue de la ponte. | Des phases configurables par race et par objectif. | Valider les âges par défaut |
| 12 | Catégories de dépenses mal utilisées : « salaire gardien » classé dans Autre (alors que Main d'œuvre existe), essence et péage dans Autre (alors que Transport existe). « salaire gardien » a même été ajouté comme catégorie dans Paramètres. | Le résultat par catégorie est faussé. | Une liste fermée de catégories, avec une sous-catégorie libre. | Valider le reclassement à l'import |
| 13 | OE-COU (« Œuf à couver », catégorie Œufs) est vendu comme « Couvaison d'œufs pour client ». Le chiffre « Œufs couvés pour clients » vaut 185 dans les ventes, mais 113 œufs dans les lots clients. | Le service de couvaison et la vente d'œufs fécondés sont mélangés. | Deux produits distincts : « Service de couvaison » et « Œuf fécondé vendu ». | Valider |
| 14 | Maquettes : elles utilisent « Oiseaux présents », arrondissent 588 256 en « 588 000 F », inventent des chiffres (66 500, Kuroiler, Bleu de Hollande dans les lots BUR, alors que BUR-26-020 est en réalité terminé) et affichent un logo « nafa. » différent du logo validé. La base d'application utilise un monogramme « N ». | Des écarts avec les règles validées. | Garder la structure des maquettes, remplacer le logo par le logo validé, n'utiliser que des données réelles ou marquées « démonstration ». | — |
| 15 | La base d'application affiche des chiffres fictifs codés en dur (1 248 500 FCFA, +12,4 %…), un lot Goliath et un lot SASSO dans « Poulets de chair », et des lots de couveuse faux (BUR-26-028 avec 120 œufs au lieu de 51, CLI-26-004 avec 80 œufs au lieu de 8). La case « couvaison et conversion » est visible pour toutes les productions. | Une démonstration trompeuse et un mélange des races. | Repartir sur un modèle de données réel ; les lots filtrés par production. | — |
| 16 | Taux d'éclosion prévisionnel de 50 % dans ProgrammeSorties, alors que le taux observé est de 58,1 %. | Prévisions de sortie sous-estimées. | Par défaut, le taux observé sur les 3 derniers mois, modifiable. | Valider |
| 17 | Le tableau de bord Excel affiche « Prochaine sortie : aucune prévue » alors que 3 échéances existent. Il affiche aussi « 251,0 poussins ». | Messages contradictoires. | — (corrigé par conception) | — |
