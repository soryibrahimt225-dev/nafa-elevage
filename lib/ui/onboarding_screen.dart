import 'package:material_ui/material_ui.dart';

import '../data/settings_store.dart';
import '../domain/production.dart';
import 'icons.dart';
import 'theme.dart';

/// Écran de bienvenue : « Quelle production voulez-vous gérer ? »
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.settings});
  final FarmSettings settings;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  ProductionType? _selected;
  final Set<OptionalFeature> _options = {};

  @override
  Widget build(BuildContext context) {
    final options = _selected == null ? const <OptionalFeature>[] : optionsFor(_selected!);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                Image.asset('assets/images/nafa_logo.png',
                    height: 64, alignment: Alignment.centerLeft, semanticLabel: 'Nafa Élevage'),
                const SizedBox(height: 24),
                Text('BIENVENUE DANS NAFA ÉLEVAGE',
                    style: TextStyle(
                        color: NafaColors.green, fontWeight: FontWeight.w700,
                        letterSpacing: 1, fontSize: 12)),
                const SizedBox(height: 8),
                const Text('Quelle production voulez-vous gérer ?',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 8),
                const Text(
                    'Choisissez votre production. Nafa affichera seulement les écrans utiles.',
                    style: TextStyle(color: NafaColors.textMuted, fontSize: 15)),
                const SizedBox(height: 20),
                for (final p in ProductionType.values) ...[
                  _ProductionTile(
                    production: p,
                    selected: _selected == p,
                    onTap: () => setState(() {
                      _selected = p;
                      _options.removeWhere((o) => !optionsFor(p).contains(o));
                    }),
                  ),
                  const SizedBox(height: 10),
                ],
                for (final o in options)
                  Card(
                    color: NafaColors.greenLight,
                    child: CheckboxListTile(
                      key: ValueKey('option-${o.name}'),
                      value: _options.contains(o),
                      onChanged: (v) => setState(() => v == true ? _options.add(o) : _options.remove(o)),
                      title: Text(optionLabel(o), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(optionHelp(o)),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('continuer'),
                  onPressed: _selected == null
                      ? null
                      : () => widget.settings.choose(_selected!, _options),
                  child: const Text('Continuer'),
                ),
                const SizedBox(height: 12),
                const Text('Vous pourrez ajouter un module plus tard dans les paramètres.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NafaColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductionTile extends StatelessWidget {
  const _ProductionTile({required this.production, required this.selected, required this.onTap});
  final ProductionType production;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? NafaColors.greenLight : NafaColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: selected ? NafaColors.green : NafaColors.border, width: selected ? 2 : 1),
        ),
        child: InkWell(
          key: ValueKey('production-${production.name}'),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: selected ? NafaColors.green : NafaColors.greenLight,
                  foregroundColor: selected ? Colors.white : NafaColors.green,
                  child: Icon(productionIcon(production)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(production.label,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(production.description,
                          style: const TextStyle(color: NafaColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(selected ? Icons.check_circle : Icons.chevron_right,
                    color: selected ? NafaColors.green : NafaColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
