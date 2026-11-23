import 'package:material_ui/material_ui.dart';

import '../data/app_data.dart';
import '../domain/format.dart';
import '../domain/health.dart';
import '../domain/incubation.dart';
import '../domain/lots.dart';
import '../domain/production.dart';
import 'theme.dart';

/// Page de démarrage, affichée à chaque ouverture : logo, ferme, date,
/// l'essentiel du jour, et « Commencer le travail » vers le tableau de bord.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key, required this.data, required this.today, required this.onStart});
  final AppData data;
  final DateTime today;
  final VoidCallback onStart;

  /// Ce qui demande de l'attention aujourd'hui.
  List<(IconData, String, bool)> _today() {
    final p = data.settings.production!;
    final out = <(IconData, String, bool)>[];
    if (p == ProductionType.couveuse) {
      final events = upcomingEvents(data.lots.incubationLots, today, days: 0);
      for (final e in events) {
        out.add((e.isHatch ? Icons.egg_alt_outlined : Icons.south, '${e.label} · ${e.lot.code}', true));
      }
      final running = data.lots.incubationLots.where((l) => !l.hasResult && l.statusAt(today) != IncubationStatus.aVerifier);
      out.add((Icons.thermostat_outlined, '${formatInt(running.length)} lot(s) d’œufs en couveuse', false));
      final toCheck = data.lots.incubationLots.where((l) => l.statusAt(today) == IncubationStatus.aVerifier).length;
      if (toCheck > 0) out.add((Icons.warning_amber_outlined, '$toCheck éclosion(s) à enregistrer', true));
    } else {
      final lots = data.lots.animalLots(p).where((l) => l.status == LotStatus.enCours).toList();
      out.add((
        Icons.grid_view_outlined,
        '${formatInt(lots.length)} lot(s) en cours · ${formatInt(lots.fold(0, (s, l) => s + l.current))} sujets',
        false
      ));
      if (p == ProductionType.pondeuses || p == ProductionType.ameliorees) {
        final layers = lots.where((l) => l.forLaying).toList();
        final missing = layers.where((l) => data.eggs.find(l.code, today) == null).length;
        if (missing > 0) out.add((Icons.egg_outlined, 'Ramassage des œufs à saisir : $missing lot(s)', true));
      }
    }
    final codes = {for (final l in data.lots.animalLots(p)) l.code};
    final care = data.health.forLots(codes, today);
    final late = care.where((r) => r.statusAt(today) == HealthStatus.enRetard).length;
    final due = care.where((r) => r.statusAt(today) == HealthStatus.aujourdhui).length;
    if (due > 0) out.add((Icons.medical_services_outlined, '$due soin(s) prévu(s) aujourd’hui', true));
    if (late > 0) out.add((Icons.medical_services_outlined, '$late soin(s) en retard', true));
    final low = data.feed.stocks.values.where((s) => s.low).length;
    if (low > 0) out.add((Icons.grass_outlined, '$low aliment(s) presque épuisé(s)', true));
    final toCollect = data.finance.accounting().global.toCollect;
    if (toCollect > 0) out.add((Icons.payments_outlined, 'Reste à recouvrer : ${formatFcfa(toCollect)}', false));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final farm = data.settings.farm;
    final owner = farm.users.isEmpty ? null : farm.users.first.name;
    final items = _today();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
              children: [
                Image.asset('assets/images/nafa_logo.png', height: 72, semanticLabel: 'Nafa Élevage'),
                const SizedBox(height: 28),
                Text(owner == null ? 'Bonjour' : 'Bonjour $owner',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  [farm.displayName, if (farm.location.isNotEmpty) farm.location].join(' · '),
                  key: const ValueKey('demarrage-ferme'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: NafaColors.green),
                ),
                const SizedBox(height: 4),
                Text('${formatLongDate(today)} · ${data.settings.production!.label}',
                    textAlign: TextAlign.center, style: const TextStyle(color: NafaColors.textMuted)),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Aujourd’hui', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      for (final (icon, text, important) in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Icon(icon, size: 22, color: important ? NafaColors.watch : NafaColors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(text,
                                  style: TextStyle(fontSize: 15, fontWeight: important ? FontWeight.w600 : FontWeight.w400)),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('commencer-travail'),
                  onPressed: onStart,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Commencer le travail'),
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 60), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
