import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../domain/format.dart';
import '../domain/incubation.dart';
import '../domain/lots.dart';
import 'theme.dart';

/// Pastille de statut : couleur + texte (jamais la couleur seule).
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, this.color, {super.key});
  final String label;
  final Color color;

  factory StatusChip.incubation(IncubationStatus s) => StatusChip(s.label, switch (s) {
        IncubationStatus.enIncubation || IncubationStatus.descenteFaite => NafaColors.ok,
        IncubationStatus.eclosionImminente => NafaColors.watch,
        IncubationStatus.aVerifier => NafaColors.urgent,
        IncubationStatus.termine => NafaColors.done,
      });

  factory StatusChip.lot(LotStatus s) =>
      StatusChip(s.label, s == LotStatus.enCours ? NafaColors.ok : NafaColors.done);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(children: [
          Icon(icon, size: 40, color: NafaColors.textMuted),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: NafaColors.textMuted)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

/// Ligne « libellé : valeur » pour les fiches.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: const TextStyle(color: NafaColors.textMuted))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w700, color: valueColor ?? NafaColors.text)),
          ),
        ]),
      );
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children, this.trailing});
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              ?trailing,
            ]),
            const SizedBox(height: 4),
            ...children,
          ]),
        ),
      );
}

/// Champ numérique entier (chiffres uniquement).
class IntField extends StatelessWidget {
  const IntField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.optional = false,
    this.min = 0,
    this.max,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final bool optional;
  final int min;
  final int? max;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return optional ? null : 'Obligatoire';
          final n = int.tryParse(v);
          if (n == null) return 'Nombre entier attendu';
          if (n < min) return 'Minimum : ${formatInt(min)}';
          if (max != null && n > max!) return 'Maximum : ${formatInt(max!)}';
          return null;
        },
      );
}

/// Bouton de choix de date (affiche la date en toutes lettres).
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.first, this.last});
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? first;
  final DateTime? last;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: first ?? DateTime(2020),
            lastDate: last ?? DateTime(2100),
            helpText: label,
          );
          if (d != null) onChanged(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.event),
          ),
          child: Text(formatDate(value)),
        ),
      );
}

void showError(BuildContext context, Object e) {
  final msg = e is ArgumentError ? '${e.message}' : '$e';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: NafaColors.urgent));
}

void showInfo(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        showCloseIcon: true,
      ));
}
