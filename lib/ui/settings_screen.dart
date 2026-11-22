import 'package:material_ui/material_ui.dart';

import '../data/settings_store.dart';
import '../domain/production.dart';
import 'theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});
  final FarmSettings settings;

  @override
  Widget build(BuildContext context) {
    final p = settings.production!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Paramètres', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            title: const Text('Production'),
            subtitle: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w700, color: NafaColors.text)),
          ),
        ),
        const SizedBox(height: 12),
        for (final o in optionsFor(p))
          Card(
            child: SwitchListTile(
              key: ValueKey('switch-${o.name}'),
              value: settings.options.contains(o),
              onChanged: (v) => settings.setOption(o, v),
              title: Text(optionLabel(o)),
              subtitle: Text(optionHelp(o)),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Changer de production'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Changer de production ?'),
                content: const Text('Vous reviendrez à l’écran de choix. Aucune donnée n’est supprimée.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Changer')),
                ],
              ),
            );
            if (ok == true) await settings.reset();
          },
        ),
      ],
    );
  }
}
