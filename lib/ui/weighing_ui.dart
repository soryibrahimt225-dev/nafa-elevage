import 'package:material_ui/material_ui.dart';

import '../data/app_data.dart';
import '../domain/format.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import '../domain/weighing.dart';
import 'theme.dart';
import 'widgets.dart';

/// Productions qui suivent le poids (croissance et indice de consommation).
bool tracksWeight(ProductionType p) => p == ProductionType.chair || p == ProductionType.ameliorees;

/// Carte « Pesées » de la fiche d'un lot.
class WeighingCard extends StatelessWidget {
  const WeighingCard({super.key, required this.data, required this.lot, required this.today});
  final AppData data;
  final AnimalLot lot;
  final DateTime today;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([data.weights, data.feed]),
        builder: (context, _) {
          final g = Growth(lot, data.weights.forLot(lot.code), data.feed.moves);
          return SectionCard(title: 'Pesées et croissance', children: [
            if (g.last == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Aucune pesée. Pesez quelques sujets et notez leur poids moyen. '
                  'Pour suivre la croissance depuis le début, faites une pesée le jour du démarrage.',
                  style: TextStyle(color: NafaColors.textMuted),
                ),
              )
            else ...[
              InfoRow('Dernier poids moyen', '${formatWeight(g.last!.averageGrams)} · ${formatDate(g.last!.date)}'),
              InfoRow('Poids estimé du lot', formatWeight(g.flockWeight!)),
              if (g.hasTwo) ...[
                InfoRow('Gain moyen', '${formatWeight(g.gainPerSubject!)} en ${g.days} jours'),
                if (g.dailyGain != null) InfoRow('Gain moyen quotidien', '${g.dailyGain!.round()} g par sujet et par jour'),
                InfoRow('Aliment entre les pesées', '${(g.feedGrams / 1000).toStringAsFixed(1).replaceAll('.', ',')} kg'),
                InfoRow('Indice de consommation', formatFcr(g.fcr)),
                if (g.fcr == null)
                  const Text('Indice non calculable : enregistrez l’aliment distribué entre les pesées.',
                      style: TextStyle(color: NafaColors.watch, fontSize: 12)),
              ] else
                const Text('Une deuxième pesée permettra de calculer le gain et l’indice de consommation.',
                    style: TextStyle(color: NafaColors.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              for (final w in g.weighings.reversed.take(6))
                InfoRow('${formatDate(w.date)} · ${lot.ageAt(w.date)} jours',
                    '${formatWeight(w.averageGrams)}${w.sampleSize > 0 ? ' (${w.sampleSize} pesés)' : ''}'),
            ],
            const SizedBox(height: 8),
            if (lot.status == LotStatus.enCours)
              OutlinedButton.icon(
                key: const ValueKey('nouvelle-pesee'),
                onPressed: () => showWeighingDialog(context, data, lot, today),
                icon: const Icon(Icons.scale_outlined),
                label: const Text('Enregistrer une pesée'),
              ),
            const Text('Indice de consommation = aliment distribué ÷ poids gagné par le lot.',
                style: TextStyle(color: NafaColors.textMuted, fontSize: 12)),
          ]);
        },
      );
}

Future<void> showWeighingDialog(BuildContext context, AppData data, AnimalLot lot, DateTime today) async {
  final avg = TextEditingController();
  final sample = TextEditingController();
  final form = GlobalKey<FormState>();
  var date = today;
  await showDialog<void>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setState) => AlertDialog(
        title: Text('Pesée · ${lot.code}'),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DateField(label: 'Date', value: date, first: lot.startDate, last: today, onChanged: (v) => setState(() => date = v)),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Âge du lot : ${lot.ageAt(date)} jours', style: const TextStyle(color: NafaColors.textMuted)),
              ),
              const SizedBox(height: 12),
              IntField(
                key: const ValueKey('poids-moyen'),
                controller: avg,
                label: 'Poids moyen d’un sujet',
                suffix: 'g',
                min: 1,
                max: 20000,
              ),
              const SizedBox(height: 12),
              IntField(
                key: const ValueKey('sujets-peses'),
                controller: sample,
                label: 'Nombre de sujets pesés (facultatif)',
                optional: true,
                max: lot.countAt(date),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(
            key: const ValueKey('valider-pesee'),
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                await data.weights.save(Weighing(
                  id: data.weights.newId(),
                  lotCode: lot.code,
                  date: date,
                  averageGrams: int.parse(avg.text),
                  sampleSize: int.tryParse(sample.text) ?? 0,
                ));
                if (d.mounted) Navigator.pop(d);
              } catch (e) {
                if (d.mounted) showError(d, e);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
}
