import 'package:material_ui/material_ui.dart';

import '../data/egg_store.dart';
import '../data/feed_store.dart';
import '../data/finance_store.dart';
import '../data/health_store.dart';
import '../data/lot_store.dart';
import '../domain/finance.dart';
import '../domain/eggs.dart';
import '../domain/feed.dart';
import '../domain/format.dart';
import '../domain/health.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import 'incubation_lots_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Tableau de bord dynamique : indicateurs de la production choisie,
/// calculés à partir des lots (traçables, jamais inventés).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.finance,
    required this.health,
    required this.eggs,
    required this.feed,
    required this.production,
    required this.options,
    required this.today,
  });
  final LotStore store;
  final FinanceStore finance;
  final HealthStore health;
  final EggStore eggs;
  final FeedStore feed;
  final ProductionType production;
  final Set<OptionalFeature> options;
  final DateTime today;

  bool get _showsIncubation =>
      production == ProductionType.couveuse ||
      options.contains(OptionalFeature.couvaisonConversion) ||
      options.contains(OptionalFeature.couveusePondeuses);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, finance, health, eggs, feed]),
      builder: (context, _) {
        final total = finance.accounting().global;
        final month = finance.accounting(Period.month(today)).global;
        final kpis = <(String, String, String?)>[
          ('Chiffre d’affaires', formatFcfa(total.sales), 'ce mois-ci : ${formatFcfa(month.sales)}'),
          ('Dépenses', formatFcfa(total.expenses), 'ce mois-ci : ${formatFcfa(month.expenses)}'),
          ('Bénéfice estimé', formatFcfa(total.profit),
              total.toCollect > 0 ? 'reste à recouvrer : ${formatFcfa(total.toCollect)}' : 'marge : ${formatPercent(total.margin)}'),
        ];
        final children = <Widget>[];

        if (production != ProductionType.couveuse) {
          final lots = store.animalLots(production);
          final active = lots.where((l) => l.status == LotStatus.enCours).toList();
          final initial = active.fold(0, (s, l) => s + l.initialCount);
          final dead = active.fold(0, (s, l) => s + l.dead);
          kpis.addAll([
            (production == ProductionType.pondeuses ? 'Sujets en ponte' : 'Sujets présents',
                '${formatInt(active.fold(0, (s, l) => s + l.current))} sujets', null),
            ('Lots en cours', formatInt(active.length), '${formatInt(lots.length)} au total'),
            ('Mortalité', initial == 0 ? '—' : formatPercent(dead / initial), '${formatInt(dead)} sujets morts'),
          ]);
          if (production == ProductionType.pondeuses) {
            final codes = {for (final l in active) l.code};
            final collected = eggs.between(codes, today, today).fold(0, (n, r) => n + r.collected);
            kpis.addAll([
              ('Œufs du jour', '${formatInt(collected)} œufs', null),
              ('Taux de ponte', formatPercent(layingRate(collected, active.fold(0, (n, l) => n + l.current))), 'aujourd’hui'),
            ]);
          }
          final care = health.forLots({for (final l in lots) l.code}, today).where((r) {
            final st = r.statusAt(today);
            return st == HealthStatus.enRetard || st == HealthStatus.aujourdhui;
          }).toList();
          final low = feed.stocks.values.where((s) => s.low).toList();
          final monthGrams = feed.moves
              .where((m) =>
                  m.type == FeedMoveType.distribution &&
                  m.date.year == today.year &&
                  m.date.month == today.month &&
                  lots.any((l) => l.code == m.lotCode))
              .fold(0, (n, m) => n + m.grams);
          if (feed.items.isNotEmpty) {
            children.add(SectionCard(title: 'Alimentation', children: [
              InfoRow('Distribué ce mois-ci', formatKg(monthGrams)),
              for (final s in low)
                InfoRow('Stock bas : ${s.item.name}', formatKg(s.remainingGrams), valueColor: NafaColors.urgent),
            ]));
          }
          children.add(SectionCard(
            title: 'Soins du jour et en retard',
            children: [
              if (care.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Aucun soin à faire aujourd’hui.', style: TextStyle(color: NafaColors.textMuted)),
                ),
              for (final r in care.take(6))
                InfoRow('${r.lotCode} · ${r.title}',
                    r.statusAt(today) == HealthStatus.enRetard ? 'en retard (${r.lateDays(today)} j)' : 'aujourd’hui',
                    valueColor: r.statusAt(today) == HealthStatus.enRetard ? NafaColors.urgent : NafaColors.watch),
            ],
          ));
          children.add(SectionCard(
            title: 'Lots en cours',
            children: [
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Aucun lot en cours. Créez un lot dans « Lots et sujets ».',
                      style: TextStyle(color: NafaColors.textMuted)),
                ),
              for (final l in active.take(6))
                InfoRow('${l.code} · ${l.breed} · ${l.ageAt(today)} jours', '${formatInt(l.current)} sujets'),
            ],
          ));
        }

        if (_showsIncubation) {
          final sum = IncubationSummary(store.incubationLots, today);
          if (production == ProductionType.couveuse) {
            kpis.addAll([
              ('Œufs en incubation', '${formatInt(sum.eggsRunning)} œufs', '${formatInt(sum.running)} lot(s) en cours'),
              ('Taux d’éclosion', formatPercent(sum.hatchRate), '${formatInt(sum.hatched)} éclos sur ${formatInt(sum.eggsWithResult)} œufs'),
              ('Poussins vivants', formatInt(sum.alive), 'mortalité à l’éclosion : ${formatPercent(sum.mortalityRate)}'),
            ]);
          }
          final events = upcomingEvents(store.incubationLots, today);
          children.add(SectionCard(
            title: 'Couvaison : 10 prochains jours',
            children: [
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Aucune descente ni éclosion prévue.', style: TextStyle(color: NafaColors.textMuted)),
                ),
              for (final e in events)
                InkWell(
                  onTap: () => openIncubationLot(context, store, e.lot, today),
                  child: InfoRow('${e.lot.code} · ${e.label}', _when(e.date)),
                ),
            ],
          ));
          if (production == ProductionType.couveuse) {
            final bands = store.animalLots(ProductionType.couveuse);
            if (bands.isNotEmpty) {
              final initial = bands.fold(0, (n, b) => n + b.initialCount);
              final dead = bands.fold(0, (n, b) => n + b.dead);
              children.add(SectionCard(title: 'Poussins gardés', children: [
                InfoRow('Bandes en cours', formatInt(bands.where((b) => b.status == LotStatus.enCours).length)),
                InfoRow('Poussins mis en élevage', formatInt(initial)),
                InfoRow('Effectif actuel', '${formatInt(bands.fold(0, (n, b) => n + b.current))} sujets'),
                InfoRow('Mortalité en élevage', formatPercent(dead / initial)),
              ]));
              // Soins des bandes (jamais des lots d'œufs).
              final care = health.forLots({for (final b in bands) b.code}, today).where((r) {
                final st = r.statusAt(today);
                return st == HealthStatus.enRetard || st == HealthStatus.aujourdhui;
              }).toList();
              if (care.isNotEmpty) {
                children.add(SectionCard(title: 'Soins des poussins gardés', children: [
                  for (final r in care.take(6))
                    InfoRow('${r.lotCode} · ${r.title}',
                        r.statusAt(today) == HealthStatus.enRetard ? 'en retard (${r.lateDays(today)} j)' : 'aujourd’hui',
                        valueColor: r.statusAt(today) == HealthStatus.enRetard ? NafaColors.urgent : NafaColors.watch),
                ]));
              }
            }
          }
          if (sum.toCheck > 0) {
            final toCheck = store.incubationLots
                .where((l) => l.suspiciousMortality || (!l.hasResult && l.statusAt(today).name == 'aVerifier'))
                .toList();
            children.add(SectionCard(
              title: 'Alertes : ${formatInt(sum.toCheck)} lot(s) à vérifier',
              children: [
                for (final l in toCheck.take(8))
                  InkWell(
                    onTap: () => openIncubationLot(context, store, l, today),
                    child: InfoRow(l.code, l.suspiciousMortality ? 'mortalité = tous les éclos' : 'éclosion non saisie',
                        valueColor: NafaColors.urgent),
                  ),
                if (toCheck.length > 8)
                  Text('… et ${toCheck.length - 8} autre(s)', style: const TextStyle(color: NafaColors.textMuted)),
              ],
            ));
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(formatLongDate(today).toUpperCase(),
                style: const TextStyle(fontSize: 12, color: NafaColors.textMuted, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(production.label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            Text(production.description, style: const TextStyle(color: NafaColors.textMuted)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 900 ? 3 : 2;
              const gap = 10.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                for (final k in kpis)
                  SizedBox(
                    width: w,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(k.$1, style: const TextStyle(fontSize: 13, color: NafaColors.textMuted)),
                          const SizedBox(height: 6),
                          Text(k.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          if (k.$3 != null) ...[
                            const SizedBox(height: 2),
                            Text(k.$3!, style: const TextStyle(fontSize: 12, color: NafaColors.textMuted)),
                          ],
                        ]),
                      ),
                    ),
                  ),
              ]);
            }),
            for (final c in children) ...[const SizedBox(height: 12), c],
          ],
        );
      },
    );
  }

  String _when(DateTime d) {
    final n = d.difference(DateTime(today.year, today.month, today.day)).inDays;
    final rel = n == 0 ? 'aujourd’hui' : n == 1 ? 'demain' : 'dans $n jours';
    return '${formatDate(d)} ($rel)';
  }
}
