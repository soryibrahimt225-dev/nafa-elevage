# Nafa Élevage

Nafa Élevage est une application web et mobile (Flutter) de gestion d'élevage, pensée pour les producteurs du Mali.

## État d'avancement

| Lot | Contenu | État |
|---|---|---|
| 1 | Structure du projet, onboarding, choix de production, menus dynamiques | ✅ livré |
| 2 | Calendrier de couvaison : calcul de la descente et de l'éclosion | ✅ livré |
| 3 | Lots de sujets (effectif, mortalité, sorties, âge) et lots d'œufs (résultat d'éclosion), enregistrés sur l'appareil ; import de l'onglet « Lots » du classeur | ✅ livré |
| 4 | Tableau de bord alimenté par les lots et la comptabilité : échéances à 10 jours, alertes | ✅ livré |
| 5 | Santé et vaccination (sauf couveuse) : soins prévus, réalisés, en retard ; aucune prescription proposée | ✅ livré |
| 6 | Ventes (remise explicite, encaissements), dépenses (générales ou par production/lot), comptabilité générale (par production, par lot, par mois) | ✅ livré |
| 7 | Production mensuelle de la couveuse, comparatif producteur / client | ✅ livré |
| 8 | Agenda du téléphone (Android et iPhone, sans Google Agenda) et notifications locales en repli ; réglages heure / veille ; suppression à l'éclosion | ✅ livré (à valider sur téléphone) |
| 8 bis | Ponte et œufs (pondeuses) ; ponte, maintien et réforme (races améliorées) : ramassage quotidien, cassés, fertiles, taux de ponte, réforme décidée par le producteur | ✅ livré |
| 8 ter | Alimentation : catalogue par stade, achats en sacs (dépense créée en même temps), distribution aux lots avec calcul de ration, pertes, stock et valeur au coût moyen, alerte de stock bas, consommation et coût par lot, par sujet et par œuf | ✅ livré |
| 8 quater | Poussins gardés : bandes EL-AA-NNN issues des éclosions (lots d'origine), mortalité, ventes, âge, santé et vaccination des bandes ; poussins disponibles par éclosion ; vente de poussins limitée aux disponibles | ✅ livré |
| 9 | Paramètres : espèces de couvaison (durée, jour de descente), races, prix de référence, cycle des races améliorées | ✅ livré |
| 10 | Rapports, sauvegarde et synchronisation | à venir |

## Règles appliquées

- Seuls les modules utiles à la production choisie sont affichés. Le menu de la couveuse n'affiche pas la vaccination : seules les bandes de poussins gardés ont un suivi santé (décision du client, voir [`docs/decisions.md`](docs/decisions.md)).
- On écrit « sujet » ou « sujets », jamais « oiseau ».
- Les montants sont toujours écrits en entier : `588 256 FCFA`.
- Couvaison : le jour de mise en couveuse est le **jour 0**, et l'éclosion tombe à la date d'entrée + la durée, comme dans le classeur `Gestion-couvoir-2026.xlsx`.
- Jours de descente proposés par défaut, modifiables dans Paramètres : Goliath 16, poule 18, pintade, canard et dindon 25, canard de Barbarie 31 (35 jours d'incubation).

Les incohérences relevées et les décisions attendues sont listées dans [`docs/audit-phase1-3.md`](docs/audit-phase1-3.md).

## Rappels sur téléphone

- Après la création d'un lot d'œufs, Nafa propose d'ajouter deux rappels (descente et éclosion) à l'**agenda natif** du téléphone (`device_calendar_plus` : Calendar Provider sur Android, EventKit sur iPhone).
- Si l'accès à l'agenda est refusé ou indisponible, Nafa programme des **notifications locales** (`flutter_local_notifications`), à une heure approximative : l'application ne demande pas l'autorisation « alarmes exactes ».
- La saisie de l'éclosion supprime les rappels restants. Dans Paramètres, on règle l'heure, le jour même ou la veille, et on peut réappliquer les réglages aux lots en cours.
- Sur le web, aucun rappel n'est créé.
- Configuration native : permissions dans `AndroidManifest.xml` (agenda, notifications, redémarrage), *desugaring* dans `android/app/build.gradle.kts`, textes d'autorisation dans `ios/Runner/Info.plist`, délégué de notifications dans `AppDelegate.swift`.

## Développement

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Version web hors connexion (CanvasKit embarqué, sans CDN) :

```bash
flutter build web --release --no-web-resources-cdn
```

Arborescence :

- `lib/domain` : règles métier pures et testées (productions, couvaison, formats).
- `lib/data` : stockage local (`shared_preferences`).
- `lib/ui` : écrans.
- `test` : tests de calcul avec les lots réels du classeur, et tests d'écran sur un téléphone de 360 px.
