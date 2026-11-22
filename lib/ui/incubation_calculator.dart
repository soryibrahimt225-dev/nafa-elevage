import 'package:material_ui/material_ui.dart';

import '../data/lot_store.dart';
import '../domain/format.dart';
import '../domain/incubation.dart';
import '../domain/lots.dart';
import 'incubation_lots_screen.dart';
import 'theme.dart';

/// Calcul des dates de couvaison (descente et éclosion) pour un lot.
/// Les lots enregistrés et l'agenda du téléphone viendront aux lots 9 et 10.
class IncubationCalculator extends StatefulWidget {
  const IncubationCalculator({super.key, required this.today, this.store});
  final DateTime today;
  final LotStore? store;

  @override
  State<IncubationCalculator> createState() => _IncubationCalculatorState();
}

class _IncubationCalculatorState extends State<IncubationCalculator> {
  SpeciesProfile _profile = defaultSpeciesProfiles.first;
  late DateTime _entry = DateTime(widget.today.year, widget.today.month, widget.today.day);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _entry,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('fr'),
      helpText: 'Date de mise en couveuse',
    );
    if (d != null) setState(() => _entry = d);
  }

  @override
  Widget build(BuildContext context) {
    final s = IncubationSchedule.forProfile(_entry, _profile);
    final day = s.dayAt(widget.today);
    final status = s.statusAt(widget.today);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Calendrier de couvaison',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        if (widget.store != null) ...[
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: widget.store!,
            builder: (context, _) {
              final events = upcomingEvents(widget.store!.incubationLots, widget.today, days: 30);
              return Card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Prochaines étapes (30 jours)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  if (events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Text('Aucune étape prévue.', style: TextStyle(color: NafaColors.textMuted)),
                    ),
                  for (final e in events)
                    ListTile(
                      leading: Icon(e.isHatch ? Icons.egg_alt_outlined : Icons.south, color: NafaColors.green),
                      title: Text('${e.lot.code} · ${e.label}'),
                      subtitle: Text('${formatDate(e.date)} · ${formatInt(e.lot.eggsSet)} œufs'),
                      onTap: () => openIncubationLot(context, widget.store!, e.lot, widget.today),
                    ),
                ]),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('Calculer des dates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 4),
        const Text('Choisissez l’espèce et la date : les dates se calculent seules.',
            style: TextStyle(color: NafaColors.textMuted)),
        const SizedBox(height: 16),
        DropdownButtonFormField<SpeciesProfile>(
          key: const ValueKey('espece'),
          initialValue: _profile,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Espèce ou race', border: OutlineInputBorder()),
          items: [
            for (final p in defaultSpeciesProfiles)
              DropdownMenuItem(
                  value: p,
                  child: Text('${p.label} · ${p.incubationDays} jours', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (p) => setState(() => _profile = p ?? _profile),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.event),
          label: Text('Mise en couveuse : ${formatDate(_entry)}'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52), alignment: Alignment.centerLeft),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(children: [
            _Step(
              icon: Icons.login,
              title: 'Mise en couveuse',
              date: formatDate(s.entryDate),
              detail: 'Jour 0',
            ),
            const Divider(height: 1),
            _Step(
              key: const ValueKey('descente'),
              icon: Icons.south,
              title: 'Descendre les œufs (arrêt du retournement)',
              date: formatDate(s.descenteDate),
              detail: 'Jour ${s.descenteDay}',
            ),
            const Divider(height: 1),
            _Step(
              key: const ValueKey('eclosion'),
              icon: Icons.egg_alt_outlined,
              title: 'Éclosion prévue',
              date: formatDate(s.hatchDate),
              detail: 'Jour ${s.incubationDays}',
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (day >= 0)
          Text('Aujourd’hui : jour $day sur ${s.incubationDays} · ${status.label}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        const Text(
          'Durées et jour de descente proposés par défaut : à adapter à votre méthode '
          'dans les paramètres de l’espèce.',
          style: TextStyle(color: NafaColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({super.key, required this.icon, required this.title, required this.date, required this.detail});
  final IconData icon;
  final String title;
  final String date;
  final String detail;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: NafaColors.green),
        title: Text(title),
        subtitle: Text('$date · $detail',
            style: const TextStyle(fontWeight: FontWeight.w700, color: NafaColors.text)),
      );
}
