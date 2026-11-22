import 'package:material_ui/material_ui.dart';

import '../data/lot_store.dart';
import '../domain/format.dart';
import '../domain/lots.dart';
import 'theme.dart';
import 'widgets.dart';

const _months = ['Janv.', 'Févr.', 'Mars', 'Avr.', 'Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.'];

/// Production mensuelle de la couveuse (logique du classeur, mois
/// d'éclosion prévue), avec comparatif producteur / client.
class MonthlyProductionScreen extends StatefulWidget {
  const MonthlyProductionScreen({super.key, required this.store});
  final LotStore store;

  @override
  State<MonthlyProductionScreen> createState() => _MonthlyProductionScreenState();
}

class _MonthlyProductionScreenState extends State<MonthlyProductionScreen> {
  OwnerType? _owner = OwnerType.producteur;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final lots = widget.store.incubationLots;
          final rows = monthlyProduction(lots, owner: _owner).reversed.toList();
          final total = totalOf(rows);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Production mensuelle', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text(
                'Par mois d’éclosion. Le taux d’éclosion ne compte que les lots dont le résultat est saisi.',
                style: TextStyle(color: NafaColors.textMuted),
              ),
              const SizedBox(height: 12),
              SegmentedButton<OwnerType?>(
                segments: const [
                  ButtonSegment(value: OwnerType.producteur, label: Text('Mes lots')),
                  ButtonSegment(value: OwnerType.client, label: Text('Clients')),
                  ButtonSegment(value: null, label: Text('Tous')),
                ],
                selected: {_owner},
                onSelectionChanged: (s) => setState(() => _owner = s.first),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const EmptyState(
                  icon: Icons.bar_chart,
                  title: 'Aucune donnée',
                  message: 'La production mensuelle se remplit avec les lots d’œufs.',
                )
              else ...[
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: NafaColors.text),
                      columnSpacing: 18,
                      columns: const [
                        DataColumn(label: Text('Mois')),
                        DataColumn(label: Text('Lots'), numeric: true),
                        DataColumn(label: Text('Œufs mis'), numeric: true),
                        DataColumn(label: Text('Avec résultat'), numeric: true),
                        DataColumn(label: Text('Éclos'), numeric: true),
                        DataColumn(label: Text('Non éclos'), numeric: true),
                        DataColumn(label: Text('Taux d’éclosion'), numeric: true),
                        DataColumn(label: Text('Mortalité'), numeric: true),
                        DataColumn(label: Text('Taux de mortalité'), numeric: true),
                        DataColumn(label: Text('Vivants'), numeric: true),
                      ],
                      rows: [
                        for (final r in rows) _row('${_months[r.month.month - 1]} ${r.month.year}', r),
                        _row('TOTAL', total, bold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Comparison(lots: lots),
              ],
            ],
          );
        },
      );

  DataRow _row(String label, MonthlyHatch r, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700) : null;
    DataCell c(String v) => DataCell(Text(v, style: style));
    return DataRow(cells: [
      c(label),
      c(formatInt(r.lots)),
      c(formatInt(r.eggsSet)),
      c(formatInt(r.eggsWithResult)),
      c(formatInt(r.hatched)),
      c(formatInt(r.unhatched)),
      c(formatPercent(r.hatchRate)),
      c(formatInt(r.deaths)),
      c(formatPercent(r.mortalityRate)),
      c(formatInt(r.alive)),
    ]);
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.lots});
  final List<IncubationLot> lots;

  @override
  Widget build(BuildContext context) {
    final prod = totalOf(monthlyProduction(lots, owner: OwnerType.producteur));
    final cli = totalOf(monthlyProduction(lots, owner: OwnerType.client));
    return SectionCard(title: 'Comparatif depuis le début', children: [
      InfoRow('Mes lots', '${formatInt(prod.lots)} lots · éclosion ${formatPercent(prod.hatchRate)} · ${formatInt(prod.alive)} vivants'),
      InfoRow('Lots clients', '${formatInt(cli.lots)} lots · éclosion ${formatPercent(cli.hatchRate)} · ${formatInt(cli.alive)} vivants'),
    ]);
  }
}
