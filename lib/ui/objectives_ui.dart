import 'package:material_ui/material_ui.dart';

import '../domain/lots.dart';
import 'theme.dart';

/// Choix des objectifs d'un lot de races améliorées : plusieurs à la fois.
class ObjectivesPicker extends StatelessWidget {
  const ObjectivesPicker({super.key, required this.value, required this.onChanged});
  final Set<LotObjective> value;
  final ValueChanged<Set<LotObjective>> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Objectifs du lot', style: TextStyle(fontWeight: FontWeight.w600)),
        const Text('Vous pouvez tout faire en même temps avec le même lot.',
            style: TextStyle(color: NafaColors.textMuted, fontSize: 13)),
        for (final o in LotObjective.values)
          CheckboxListTile(
            key: ValueKey('objectif-${o.name}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: value.contains(o),
            title: Text(o.label),
            onChanged: (v) => onChanged(v == true ? {...value, o} : ({...value}..remove(o))),
          ),
      ]);
}
