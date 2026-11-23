import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_service.dart';
import '../domain/format.dart';
import 'app_scope.dart';
import 'theme.dart';
import 'widgets.dart';

/// Paramètres > Sauvegarde : créer un fichier, restaurer, annuler.
class BackupSection extends StatefulWidget {
  const BackupSection({super.key, required this.service, required this.farmName});
  final BackupService service;
  final String farmName;

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final bytes = await widget.service.export();
      final name = widget.service.fileName(widget.farmName);
      await SharePlus.instance.share(ShareParams(
        title: 'Sauvegarde Nafa Élevage',
        files: [XFile.fromData(bytes, name: name, mimeType: 'application/json')],
        fileNameOverrides: [name],
      ));
      if (mounted) showInfo(context, 'Sauvegarde créée : $name. Gardez ce fichier en lieu sûr.');
    } catch (e) {
      if (mounted) showError(context, 'Sauvegarde impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
    if (picked.isEmpty || !mounted) return;
    final bytes = await picked.single.readAsBytes();
    if (!mounted) return;
    final BackupInfo info;
    try {
      info = widget.service.inspect(bytes);
    } on FormatException catch (e) {
      showError(context, e.message);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: Text('${info.summary}.\n\n'
            'Toutes les données actuelles de ce téléphone seront remplacées. '
            'Vous pourrez revenir en arrière juste après.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(
              key: const ValueKey('confirmer-restauration'),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Restaurer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.service.restore(bytes);
      if (!mounted) return;
      final reload = AppScope.reloadOf(context);
      showInfo(context, 'Sauvegarde restaurée. Pensez à recréer les rappels dans Paramètres.');
      await reload?.call();
    } on FormatException catch (e) {
      if (mounted) showError(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Efface toutes les données de l'appareil et revient à l'écran de départ.
  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Recommencer à zéro ?'),
        content: const Text(
          'Toutes les données de ce téléphone seront effacées : lots, ventes, dépenses, aliments, soins, '
          'paramètres et ferme. L’application reviendra à la première question.\n\n'
          'Créez d’abord une sauvegarde si vous voulez pouvoir les retrouver.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(
            key: const ValueKey('confirmer-recommencer'),
            style: FilledButton.styleFrom(backgroundColor: NafaColors.urgent),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final reload = AppScope.reloadOf(context);
    await widget.service.resetAll();
    await reload?.call();
  }

  Future<void> _undo() async {
    await widget.service.undoRestore();
    if (!mounted) return;
    final reload = AppScope.reloadOf(context);
    showInfo(context, 'Données d’avant la restauration remises en place.');
    await reload?.call();
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.service.lastBackupAt;
    return SectionCard(title: 'Sauvegarde', children: [
      const Text(
        'Toutes vos données dans un seul fichier, à garder sur un autre téléphone, dans WhatsApp ou par e-mail. '
        'Utile pour changer de téléphone ou en cas de perte.',
        style: TextStyle(color: NafaColors.textMuted, fontSize: 13),
      ),
      const SizedBox(height: 6),
      InfoRow('Dernière sauvegarde', last == null ? 'jamais' : formatDate(last),
          valueColor: last == null ? NafaColors.watch : null),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
          key: const ValueKey('creer-sauvegarde'),
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.save_alt),
          label: const Text('Créer une sauvegarde'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('restaurer'),
          onPressed: _busy ? null : _restore,
          icon: const Icon(Icons.restore),
          label: const Text('Restaurer depuis un fichier'),
        ),
        TextButton.icon(
          key: const ValueKey('recommencer'),
          style: TextButton.styleFrom(foregroundColor: NafaColors.urgent),
          onPressed: _busy ? null : _reset,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Recommencer à zéro'),
        ),
        if (widget.service.canUndoRestore)
          TextButton(
            key: const ValueKey('annuler-restauration'),
            onPressed: _busy ? null : _undo,
            child: const Text('Annuler la dernière restauration'),
          ),
      ]),
    ]);
  }
}
