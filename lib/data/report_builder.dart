import '../domain/eggs.dart';
import '../domain/finance.dart';
import '../domain/format.dart';
import '../domain/health.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import '../domain/report.dart';
import 'app_data.dart';

/// Rapports du dossier de spécification (section 7).
enum ReportKind {
  mensuel('Rapport mensuel'),
  financier('Rapport financier'),
  lot('Rapport du lot'),
  race('Rapport par race'),
  ponte('Rapport de ponte'),
  couvaison('Rapport de couvaison');

  const ReportKind(this.label);
  final String label;
}

/// Rapports proposés selon la production et ses options.
List<ReportKind> reportKindsFor(ProductionType p, Set<OptionalFeature> options) {
  final couvaison = p == ProductionType.couveuse ||
      options.contains(OptionalFeature.couvaisonConversion) ||
      options.contains(OptionalFeature.couveusePondeuses);
  return [
    ReportKind.mensuel,
    ReportKind.financier,
    if (p != ProductionType.couveuse) ...[ReportKind.lot, ReportKind.race],
    if (p == ProductionType.couveuse) ReportKind.lot, // bandes de poussins gardés
    if (p == ProductionType.pondeuses || p == ProductionType.ameliorees) ReportKind.ponte,
    if (couvaison) ReportKind.couvaison,
  ];
}

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];
String periodLabel(DateTime? month) => month == null ? 'depuis le début' : '${_months[month.month - 1]} ${month.year}';

class ReportBuilder {
  ReportBuilder(this.data, {required this.today});
  final AppData data;
  final DateTime today;

  ProductionType get _p => data.settings.production!;

  bool _inPeriod(DateTime d, DateTime? month) => month == null || (d.year == month.year && d.month == month.month);

  String _subtitle(DateTime? month) => '${_p.label} · ${periodLabel(month)} · établi le ${formatDate(today)}';

  Report build(ReportKind kind, {DateTime? month, String? lotCode}) => switch (kind) {
        ReportKind.financier => financial(month: month),
        ReportKind.lot => lot(lotCode!),
        ReportKind.race => byBreed(),
        ReportKind.ponte => laying(month: month),
        ReportKind.couvaison => hatching(month: month),
        ReportKind.mensuel => monthly(month ?? DateTime(today.year, today.month)),
      };

  // ─────────────────────────── Financier ───────────────────────────

  List<ReportSection> _financialSections(DateTime? month) {
    final acc = data.finance.accounting(month == null ? const Period.all() : Period.month(month));
    final g = acc.global;
    final byProd = acc.byProduction;
    final unpaid = <String, int>{};
    for (final s in data.finance.sales.where((s) => _inPeriod(s.date, month) && s.remaining > 0)) {
      final k = s.client.isEmpty ? 'Client non précisé' : s.client;
      unpaid[k] = (unpaid[k] ?? 0) + s.remaining;
    }
    return [
      ReportSection('Résultat', rows: [
        ('Chiffre d’affaires', RV.money(g.sales)),
        ('Dépenses', RV.money(g.expenses)),
        ('Bénéfice', RV.money(g.profit)),
        ('Marge', RV.pct(g.margin)),
        ('Encaissé', RV.money(g.collected)),
        ('Reste à recouvrer', RV.money(g.toCollect)),
        ('Payé', RV.money(g.paid)),
        ('Reste à payer', RV.money(g.toPay)),
        ('Trésorerie (encaissé − payé)', RV.money(g.cash)),
        if (g.discounts > 0) ('Remises accordées', RV.money(g.discounts)),
      ]),
      ReportSection('Résultat par production',
          table: ReportTable(headers: const [
            'Production',
            'Ventes (FCFA)',
            'Dépenses (FCFA)',
            'Résultat (FCFA)'
          ], rows: [
            for (final p in [...ProductionType.values, null])
              if (byProd[p] != null)
                [
                  RV.text(p?.label ?? 'Toute la ferme (dépenses générales)'),
                  RV.money(byProd[p]!.sales),
                  RV.money(byProd[p]!.expenses),
                  RV.money(byProd[p]!.profit),
                ],
          ], totals: [
            const RV.text('Total'),
            RV.money(g.sales),
            RV.money(g.expenses),
            RV.money(g.profit)
          ]),
          note: 'Les dépenses générales de la ferme restent à part : elles ne sont pas réparties entre les lots.'),
      ReportSection('Ventes par catégorie',
          table: ReportTable(headers: const ['Catégorie', 'Montant (FCFA)'], rows: [
            for (final e in acc.salesByCategory.entries) [RV.text(e.key.label), RV.money(e.value)],
          ])),
      ReportSection('Dépenses par catégorie',
          table: ReportTable(headers: const ['Catégorie', 'Montant (FCFA)'], rows: [
            for (final e in acc.expensesByCategory.entries) [RV.text(e.key.label), RV.money(e.value)],
          ])),
      if (unpaid.isNotEmpty)
        ReportSection('Reste à recouvrer par client',
            table: ReportTable(headers: const ['Client', 'Reste (FCFA)'], rows: [
              for (final e in unpaid.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                [RV.text(e.key), RV.money(e.value)],
            ])),
    ];
  }

  Report financial({DateTime? month}) {
    final all = data.finance.accounting();
    return Report(
      title: 'Rapport financier',
      subtitle: _subtitle(month),
      generatedAt: today,
      sections: [
        ..._financialSections(month),
        if (month == null && all.monthly.isNotEmpty)
          ReportSection('Évolution mensuelle',
              table: ReportTable(headers: const [
                'Mois',
                'Ventes (FCFA)',
                'Dépenses (FCFA)',
                'Résultat (FCFA)'
              ], rows: [
                for (final (m, t) in all.monthly)
                  [RV.text(periodLabel(m)), RV.money(t.sales), RV.money(t.expenses), RV.money(t.profit)],
              ])),
      ],
    );
  }

  // ───────────────────────────── Lot ─────────────────────────────

  /// Résultat du lot = ventes du lot − dépenses rattachées au lot − coût de
  /// l'aliment distribué (les achats d'aliment ne sont pas rattachés aux
  /// lots : pas de double comptage).
  (int sales, int direct, int feed, int result) lotResult(String code) {
    final sales = data.finance.sales.where((s) => s.lotCode == code).fold(0, (n, s) => n + s.amount);
    final direct = data.finance.expenses.where((e) => e.lotCode == code).fold(0, (n, e) => n + e.amount);
    final feed = data.feed.forLot(code).costFcfa;
    return (sales, direct, feed, sales - direct - feed);
  }

  Report lot(String code) {
    final l = data.lots.animalLots(_p).firstWhere((x) => x.code == code);
    final f = data.feed.forLot(code);
    final (sales, direct, feed, result) = lotResult(code);
    final care = data.health.forLots({code}, today);
    final eggs = EggSummary(data.eggs.forLots({code}));
    return Report(
      title: 'Rapport du lot $code',
      subtitle: '${l.breed} · ${_p.label} · établi le ${formatDate(today)}',
      generatedAt: today,
      sections: [
        ReportSection('Effectif', rows: [
          ('Démarré le', RV.date(l.startDate)),
          ('Âge', RV.text('${l.ageAt(today)} jours')),
          if (l.objective != null) ('Objectif', RV.text(l.objective!.label)),
          if (l.isChickBand)
            ('Origine', RV.text(l.origins.entries.map((e) => '${e.key} (${formatInt(e.value)})').join(', '))),
          ('Effectif de départ', RV.integer(l.initialCount)),
          ('Mortalité', RV.integer(l.dead)),
          ('Taux de mortalité', RV.pct(l.mortalityRate)),
          ('Vendus', RV.integer(l.countOf(MovementType.vente))),
          ('Réformés', RV.integer(l.countOf(MovementType.reforme))),
          ('Effectif actuel', RV.integer(l.current)),
          ('Statut', RV.text(l.status.label)),
        ]),
        ReportSection('Alimentation', rows: [
          ('Aliment distribué', RV.kg(f.grams)),
          ('Coût de l’aliment distribué', RV.money(f.costFcfa)),
          if (l.current > 0 && f.grams > 0) ('Coût alimentaire par sujet présent', RV.money((f.cost / l.current).round())),
          if (eggs.table > 0) ('Coût alimentaire par œuf de table', RV.money((f.cost / eggs.table).round())),
        ], note: f.unpricedGrams > 0 ? 'Coût incomplet : aliment distribué sans prix d’achat.' : null),
        if (eggs.collected > 0)
          ReportSection('Ponte', rows: [
            ('Œufs ramassés', RV.integer(eggs.collected)),
            ('Œufs cassés', RV.integer(eggs.broken)),
            ('Œufs fertiles mis de côté', RV.integer(eggs.fertile)),
            ('Œufs de table', RV.integer(eggs.table)),
          ]),
        ReportSection('Santé et vaccination', rows: [
          ('Soins réalisés', RV.integer(care.where((r) => r.statusAt(today) == HealthStatus.realise).length)),
          ('Soins en retard', RV.integer(care.where((r) => r.statusAt(today) == HealthStatus.enRetard).length)),
          ('Soins à venir',
              RV.integer(care.where((r) => r.statusAt(today) == HealthStatus.aVenir || r.statusAt(today) == HealthStatus.aujourdhui).length)),
        ]),
        ReportSection('Résultat du lot', rows: [
          ('Ventes du lot', RV.money(sales)),
          ('Dépenses rattachées au lot', RV.money(direct)),
          ('Coût de l’aliment distribué', RV.money(feed)),
          ('Résultat', RV.money(result)),
        ], note: 'Résultat = ventes du lot − dépenses rattachées au lot − aliment distribué. '
            'Les dépenses générales de la ferme ne sont pas réparties.'),
      ],
    );
  }

  // ───────────────────────────── Race ─────────────────────────────

  Report byBreed() {
    final lots = data.lots.animalLots(_p);
    final breeds = <String, List<AnimalLot>>{};
    for (final l in lots) {
      breeds.putIfAbsent(l.breed, () => []).add(l);
    }
    final rows = <List<RV>>[];
    for (final e in breeds.entries) {
      final initial = e.value.fold(0, (n, l) => n + l.initialCount);
      final dead = e.value.fold(0, (n, l) => n + l.dead);
      final grams = e.value.fold(0, (n, l) => n + data.feed.forLot(l.code).grams);
      final sales = e.value.fold(0, (n, l) => n + lotResult(l.code).$1);
      final result = e.value.fold(0, (n, l) => n + lotResult(l.code).$4);
      rows.add([
        RV.text(e.key),
        RV.integer(e.value.length),
        RV.integer(initial),
        RV.integer(e.value.fold(0, (n, l) => n + l.current)),
        RV.pct(initial == 0 ? null : dead / initial),
        RV.kg(grams),
        RV.money(sales),
        RV.money(result),
      ]);
    }
    return Report(
      title: 'Rapport par race',
      subtitle: _subtitle(null),
      generatedAt: today,
      sections: [
        ReportSection('Comparaison des races',
            table: ReportTable(headers: const [
              'Race',
              'Lots',
              'Sujets au départ',
              'Sujets actuels',
              'Mortalité (%)',
              'Aliment (kg)',
              'Ventes (FCFA)',
              'Résultat (FCFA)'
            ], rows: rows),
            note: 'Résultat par lot = ventes − dépenses rattachées − aliment distribué.'),
      ],
    );
  }

  // ───────────────────────────── Ponte ─────────────────────────────

  Report laying({DateTime? month}) {
    final lots = data.lots
        .animalLots(_p)
        .where((l) => _p == ProductionType.pondeuses || l.objective != LotObjective.engraissement)
        .toList();
    final rows = <List<RV>>[];
    var hensDays = 0;
    final all = <EggRecord>[];
    for (final l in lots) {
      final recs = data.eggs.forLots({l.code}).where((r) => _inPeriod(r.date, month)).toList();
      if (recs.isEmpty) continue;
      all.addAll(recs);
      final s = EggSummary(recs);
      final hd = recs.fold(0, (n, r) => n + l.countAt(r.date));
      hensDays += hd;
      rows.add([
        RV.text('${l.code} · ${l.breed}'),
        RV.integer(s.days.length),
        RV.integer(s.collected),
        RV.integer(s.broken),
        RV.integer(s.fertile),
        RV.integer(s.table),
        RV.pct(layingRate(s.collected, hd)),
      ]);
    }
    final t = EggSummary(all);
    final sold = data.finance.sales
        .where((s) =>
            s.production == _p &&
            (s.category == SaleCategory.oeufsTable || s.category == SaleCategory.oeufsFertiles) &&
            _inPeriod(s.date, month))
        .toList();
    return Report(
      title: 'Rapport de ponte',
      subtitle: _subtitle(month),
      generatedAt: today,
      sections: [
        ReportSection('Synthèse', rows: [
          ('Œufs ramassés', RV.integer(t.collected)),
          ('Œufs cassés', RV.integer(t.broken)),
          ('Taux de casse', RV.pct(t.brokenRate)),
          ('Œufs fertiles mis de côté', RV.integer(t.fertile)),
          ('Œufs de table', RV.integer(t.table)),
          ('Taux de ponte moyen', RV.pct(layingRate(t.collected, hensDays))),
          ('Œufs vendus', RV.integer(sold.fold(0, (n, s) => n + s.quantity))),
          ('Ventes d’œufs', RV.money(sold.fold(0, (n, s) => n + s.amount))),
        ]),
        ReportSection('Par lot',
            table: ReportTable(headers: const [
              'Lot',
              'Jours saisis',
              'Ramassés',
              'Cassés',
              'Fertiles',
              'Œufs de table',
              'Taux de ponte (%)'
            ], rows: rows),
            note: 'Taux de ponte = œufs ramassés ÷ sujets présents, sur les jours saisis.'),
      ],
    );
  }

  // ─────────────────────────── Couvaison ───────────────────────────

  Report hatching({DateTime? month}) {
    final all = data.lots.incubationLots;
    final lots = all.where((l) => _inPeriod(l.schedule.hatchDate, month)).toList();
    final mine = totalOf(monthlyProduction(lots, owner: OwnerType.producteur));
    final clients = totalOf(monthlyProduction(lots, owner: OwnerType.client));
    final bands = data.lots.animalLots(ProductionType.couveuse);
    var kept = 0, sold = 0, available = 0;
    for (final l in lots.where((l) => l.ownerType == OwnerType.producteur && l.hasResult)) {
      final b = ChickBalance(lot: l, bands: bands, sold: data.finance.chicksSoldFrom(l.code));
      kept += b.kept;
      sold += b.sold;
      available += b.available;
    }
    List<RV> line(String label, MonthlyHatch r) => [
          RV.text(label),
          RV.integer(r.lots),
          RV.integer(r.eggsSet),
          RV.integer(r.eggsWithResult),
          RV.integer(r.hatched),
          RV.integer(r.unhatched),
          RV.pct(r.hatchRate),
          RV.integer(r.deaths),
          RV.integer(r.alive),
        ];
    final rows = monthlyProduction(lots);
    return Report(
      title: 'Rapport de couvaison',
      subtitle: _subtitle(month),
      generatedAt: today,
      sections: [
        ReportSection('Mes lots', rows: [
          ('Lots', RV.integer(mine.lots)),
          ('Œufs mis en couveuse', RV.integer(mine.eggsSet)),
          ('Poussins éclos', RV.integer(mine.hatched)),
          ('Œufs non éclos', RV.integer(mine.unhatched)),
          ('Taux d’éclosion', RV.pct(mine.hatchRate)),
          ('Mortalité à l’éclosion', RV.integer(mine.deaths)),
          ('Poussins vivants', RV.integer(mine.alive)),
          ('Poussins gardés en bande', RV.integer(kept)),
          ('Poussins vendus', RV.integer(sold)),
          ('Poussins disponibles', RV.integer(available)),
        ], note: 'Taux d’éclosion calculé sur les seuls lots dont le résultat est saisi.'),
        ReportSection('Lots clients', rows: [
          ('Lots', RV.integer(clients.lots)),
          ('Œufs couvés pour les clients', RV.integer(clients.eggsSet)),
          ('Taux d’éclosion', RV.pct(clients.hatchRate)),
        ]),
        if (month == null && rows.isNotEmpty)
          ReportSection('Par mois d’éclosion',
              table: ReportTable(headers: const [
                'Mois',
                'Lots',
                'Œufs mis',
                'Avec résultat',
                'Éclos',
                'Non éclos',
                'Taux d’éclosion (%)',
                'Mortalité',
                'Vivants'
              ], rows: [
                for (final r in rows) line(periodLabel(r.month), r),
              ], totals: line('Total', totalOf(rows)))),
        ReportSection('Détail des lots',
            table: ReportTable(headers: const [
              'Lot',
              'Propriétaire',
              'Mise en couveuse',
              'Œufs',
              'Éclos',
              'Taux (%)',
              'Vivants'
            ], rows: [
              for (final l in lots)
                [
                  RV.text(l.code),
                  RV.text(l.ownerName),
                  RV.date(l.entryDate),
                  RV.integer(l.eggsSet),
                  l.hatched == null ? const RV.text('—') : RV.integer(l.hatched!),
                  RV.pct(l.hatchRate),
                  l.alive == null ? const RV.text('—') : RV.integer(l.alive!),
                ],
            ])),
      ],
    );
  }

  // ─────────────────────────── Mensuel ───────────────────────────

  /// Rapport mensuel : résultat financier du mois et activité de la
  /// production (lots, ponte ou couvaison).
  Report monthly(DateTime month) {
    final sections = <ReportSection>[..._financialSections(month)];
    if (_p == ProductionType.couveuse) {
      sections.addAll(hatching(month: month).sections.where((s) => s.title != 'Détail des lots'));
    } else {
      final lots = data.lots.animalLots(_p);
      final active = lots.where((l) => l.status == LotStatus.enCours).toList();
      final deadInMonth = lots.fold(
          0,
          (n, l) =>
              n + l.movements.where((m) => m.type == MovementType.mortalite && _inPeriod(m.date, month)).fold(0, (a, m) => a + m.count));
      final grams = data.feed.moves
          .where((m) => m.lotCode != null && lots.any((l) => l.code == m.lotCode) && _inPeriod(m.date, month))
          .fold(0, (n, m) => n + m.grams);
      sections.add(ReportSection('Lots et sujets', rows: [
        ('Lots en cours', RV.integer(active.length)),
        ('Sujets présents', RV.integer(active.fold(0, (n, l) => n + l.current))),
        ('Mortalité du mois', RV.integer(deadInMonth)),
        ('Aliment distribué dans le mois', RV.kg(grams)),
      ]));
      if (_p == ProductionType.pondeuses || _p == ProductionType.ameliorees) {
        final s = laying(month: month).sections.first;
        if ((s.rows.first.$2.value! as int) > 0) sections.add(ReportSection('Ponte', rows: s.rows, note: s.note));
      }
    }
    return Report(title: 'Rapport mensuel', subtitle: _subtitle(month), generatedAt: today, sections: sections);
  }
}
