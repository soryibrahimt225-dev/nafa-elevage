# Nafa Élevage

Nafa Élevage est une application web et mobile (Flutter) de gestion d'élevage, pensée pour les producteurs du Mali.

## État d'avancement

| Lot | Contenu | État |
|---|---|---|
| 1 | Structure du projet, onboarding, choix de production, menus dynamiques | ✅ livré |
| 2 | Calendrier de couvaison : calcul de la descente et de l'éclosion | ✅ calcul livré (lots enregistrés au lot 9) |
| 3 | Lots, effectifs, âge en jours | à venir |
| 4 | Tableau de bord alimenté par les données | à venir |
| 5 | Santé et vaccination (sauf couveuse) | à venir |
| 6 | Ventes, dépenses et comptabilité générale | à venir |
| 7 | Production mensuelle de la couveuse | à venir |
| 8 | Agenda du téléphone et notifications locales | à venir |
| 9 | Paramètres par espèce et par race, prix | à venir |
| 10 | Rapports, sauvegarde et synchronisation | à venir |

## Règles appliquées

- Seuls les modules utiles à la production choisie sont affichés. La couveuse n'affiche jamais la vaccination.
- On écrit « sujet » ou « sujets », jamais « oiseau ».
- Les montants sont toujours écrits en entier : `588 256 FCFA`.
- Couvaison : le jour de mise en couveuse est le **jour 0**, et l'éclosion tombe à la date d'entrée + la durée, comme dans le classeur `Gestion-couvoir-2026.xlsx`.
- Jours de descente proposés par défaut, modifiables : Goliath 16, poule 18, pintade, canard et dindon 25, canard de Barbarie 31 (35 jours d'incubation).

Les incohérences relevées et les décisions attendues sont listées dans [`docs/audit-phase1-3.md`](docs/audit-phase1-3.md).

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
