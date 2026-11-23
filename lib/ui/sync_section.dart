import 'package:material_ui/material_ui.dart';

import '../data/sync_api.dart';
import '../data/sync_service.dart';
import '../domain/format.dart';
import 'app_scope.dart';
import 'theme.dart';
import 'widgets.dart';

/// Paramètres > Compte et synchronisation.
class SyncSection extends StatefulWidget {
  const SyncSection({super.key, required this.sync, required this.farmName, required this.location});
  final SyncService sync;
  final String farmName;
  final String location;

  @override
  State<SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends State<SyncSection> {
  List<RemoteFarm>? _farms;
  bool _working = false;

  SyncService get s => widget.sync;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } on SyncException catch (e) {
      if (mounted) showError(context, e.message);
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _afterSync(SyncReport r) async {
    if (!mounted) return;
    final reload = AppScope.reloadOf(context);
    showInfo(context, r.message);
    if (r.changedLocally) await reload?.call();
  }

  Future<void> _editServer() async {
    final c = TextEditingController(text: s.serverUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Adresse du serveur'),
        content: TextField(
          key: const ValueKey('adresse-serveur'),
          controller: c,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
              labelText: 'Adresse', hintText: 'https://nafa.exemple.ml', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(
              key: const ValueKey('valider-serveur'), onPressed: () => Navigator.pop(d, c.text), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (url != null) await _run(() => s.setServer(url));
  }

  Future<void> _account({required bool create}) async {
    final phone = TextEditingController(), name = TextEditingController(), pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(create ? 'Créer un compte' : 'Se connecter'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const ValueKey('compte-telephone'),
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Numéro de téléphone', border: OutlineInputBorder()),
            ),
            if (create) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('compte-nom'),
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Votre nom', border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('compte-mot-de-passe'),
              controller: pass,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                helperText: create ? 'Au moins 6 caractères' : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(
            key: const ValueKey('valider-compte'),
            onPressed: () => Navigator.pop(d, true),
            child: Text(create ? 'Créer' : 'Se connecter'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final farms = create ? await s.register(phone.text, name.text, pass.text) : await s.login(phone.text, pass.text);
      setState(() => _farms = farms);
    });
  }

  Future<void> _members() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _MembersScreen(sync: s)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final busy = _working || s.busy;
          final children = <Widget>[
            const Text(
              'Un compte permet de partager la ferme entre plusieurs téléphones. '
              'Chaque personne a un rôle qui fixe ce qu’elle peut modifier.',
              style: TextStyle(color: NafaColors.textMuted, fontSize: 13),
            ),
            ListTile(
              key: const ValueKey('serveur'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Serveur'),
              subtitle: Text(s.serverUrl.isEmpty ? 'Non configuré' : s.serverUrl),
              trailing: const Icon(Icons.edit_outlined),
              onTap: busy || s.loggedIn ? null : _editServer,
            ),
          ];
          if (!s.loggedIn) {
            children.add(Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(
                key: const ValueKey('se-connecter'),
                onPressed: busy || s.serverUrl.isEmpty ? null : () => _account(create: false),
                child: const Text('Se connecter'),
              ),
              OutlinedButton(
                key: const ValueKey('creer-compte'),
                onPressed: busy || s.serverUrl.isEmpty ? null : () => _account(create: true),
                child: const Text('Créer un compte'),
              ),
            ]));
          } else {
            children.add(InfoRow('Compte', '${s.userName} · ${s.userPhone}'));
            if (s.farmId == null) {
              final farms = _farms;
              children.addAll([
                if (farms == null)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _run(() async {
                              final f = await s.farms();
                              setState(() => _farms = f);
                            }),
                    child: const Text('Voir mes fermes sur le serveur'),
                  )
                else ...[
                  if (farms.isEmpty)
                    const Text('Aucune ferme sur le serveur pour ce compte.', style: TextStyle(color: NafaColors.textMuted)),
                  for (final f in farms)
                    ListTile(
                      key: ValueKey('ferme-${f.id}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(f.name),
                      subtitle: Text(roleLabels[f.role] ?? f.role),
                      trailing: const Text('Rejoindre'),
                      onTap: busy ? null : () => _run(() async => _afterSync(await s.joinFarm(f))),
                    ),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('creer-ferme-serveur'),
                  onPressed: busy ? null : () => _run(() async => _afterSync(await s.createFarm(widget.farmName, widget.location))),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text('Mettre « ${widget.farmName} » sur le serveur'),
                ),
              ]);
            } else {
              final pending = s.pendingKeys.length;
              children.addAll([
                InfoRow('Ferme', s.farmName),
                InfoRow('Votre rôle', s.roleLabel),
                InfoRow('Dernière synchronisation', s.lastSyncAt == null ? 'jamais' : formatDate(s.lastSyncAt!)),
                InfoRow('À envoyer', pending == 0 ? 'rien' : '$pending donnée(s) modifiée(s)',
                    valueColor: pending > 0 ? NafaColors.watch : null),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    key: const ValueKey('synchroniser'),
                    onPressed: busy ? null : () => _run(() async => _afterSync(await s.sync())),
                    icon: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync),
                    label: const Text('Synchroniser'),
                  ),
                  if (s.canManageMembers)
                    OutlinedButton.icon(
                      key: const ValueKey('membres'),
                      onPressed: busy ? null : _members,
                      icon: const Icon(Icons.group_outlined),
                      label: const Text('Membres et rôles'),
                    ),
                ]),
              ]);
            }
            children.add(TextButton(
              key: const ValueKey('se-deconnecter'),
              onPressed: busy ? null : () => _run(s.logout),
              child: const Text('Se déconnecter (les données restent sur le téléphone)'),
            ));
          }
          return SectionCard(title: 'Compte et synchronisation', children: children);
        },
      );
}

class _MembersScreen extends StatefulWidget {
  const _MembersScreen({required this.sync});
  final SyncService sync;

  @override
  State<_MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<_MembersScreen> {
  late Future<List<RemoteMember>> _list = widget.sync.members();

  Future<void> _add() async {
    final phone = TextEditingController();
    var role = 'employe';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: const Text('Ajouter un membre'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('La personne doit d’abord créer son compte Nafa avec son numéro.',
                style: TextStyle(color: NafaColors.textMuted)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('membre-telephone'),
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Numéro de téléphone', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: role,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Rôle', border: OutlineInputBorder()),
              items: [for (final e in roleLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => role = v ?? role),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.sync.addMember(phone.text, role);
      setState(() => _list = widget.sync.members());
    } on SyncException catch (e) {
      if (mounted) showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Membres et rôles')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Ajouter'),
        ),
        body: FutureBuilder<List<RemoteMember>>(
          future: _list,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
              for (final m in snap.data!)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(m.name),
                    subtitle: Text('${roleLabels[m.role] ?? m.role} · ${m.phone}'),
                    trailing: m.phone == widget.sync.userPhone
                        ? const Text('Vous')
                        : IconButton(
                            tooltip: 'Retirer',
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: () async {
                              try {
                                await widget.sync.removeMember(m.id);
                                setState(() => _list = widget.sync.members());
                              } on SyncException catch (e) {
                                if (context.mounted) showError(context, e.message);
                              }
                            },
                          ),
                  ),
                ),
            ]);
          },
        ),
      );
}
