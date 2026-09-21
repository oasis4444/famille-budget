import 'dart:io';

import 'package:file_selector/file_selector.dart' show openFile;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _tile(BuildContext c, IconData icon, String title, String sub, VoidCallback onTap) =>
      Panel(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(children: [
          IconBubble(icon, C.rice),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (sub.isNotEmpty)
                Text(sub, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final me = app.me;
        return Scaffold(
          appBar: AppBar(title: Text(tr('Réglages'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            children: [
              Panel(
                child: Row(children: [
                  if (me != null) Avatar(me.s('name'), Color(me.i('color')), size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(me?.s('name') ?? '',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(app.isParent ? tr('Parent') : tr('Enfant'),
                          style: const TextStyle(color: Colors.grey)),
                    ]),
                  ),
                  TextButton(
                      onPressed: () => app.setMe(null), child: Text(tr('Changer de profil'))),
                ]),
              ),
              _tile(context, Icons.lock_outline_rounded, tr('Code PIN'),
                  me?.s('pin').isEmpty ?? true ? 'Aucun code défini' : 'Code défini', () async {
                final pin = await _askPin(context);
                if (pin != null && me != null) {
                  await app.save('members', {...me, 'pin': pin});
                }
              }),
              SectionTitle(tr('Langue')),
              Panel(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'fr', label: Text('Français')),
                    ButtonSegment(value: 'mg', label: Text('Malagasy')),
                  ],
                  selected: {lang},
                  onSelectionChanged: (s) => app.setLang(s.first),
                ),
              ),
              SectionTitle(tr('Thème')),
              Panel(
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'system', label: Text(tr('Auto'))),
                    ButtonSegment(value: 'light', label: Text(tr('Clair'))),
                    ButtonSegment(value: 'dark', label: Text(tr('Sombre'))),
                  ],
                  selected: {
                    app.themeMode == ThemeMode.dark
                        ? 'dark'
                        : app.themeMode == ThemeMode.light
                            ? 'light'
                            : 'system'
                  },
                  onSelectionChanged: (s) => app.setTheme(s.first),
                ),
              ),
              if (app.isParent) ...[
                const SectionTitle('Gestion du foyer'),
                _tile(context, Icons.home_rounded, 'Nom de la famille', app.familyName, () async {
                  final n = await askText(context, 'Nom de la famille', initial: app.familyName);
                  if (n != null && n.isNotEmpty) app.setFamily(n);
                }),
                _tile(context, Icons.groups_rounded, tr('Membres'), '${app.members.length}',
                    () => _push(context, const MembersPage())),
                _tile(context, Icons.account_balance_wallet_rounded, tr('Sources de revenus'),
                    'Papa, Maman, voitures…', () => _push(context, const SourcesPage())),
                _tile(context, Icons.category_rounded, tr('Catégories'),
                    'Catégories et sous-catégories', () => _push(context, const CategoriesPage())),
                _tile(context, Icons.payments_rounded, tr('Comptes'),
                    'Espèces, MVola, Orange Money…', () => _push(context, const AccountsPage())),
                _tile(context, Icons.repeat_rounded, tr('Récurrents'),
                    '${app.recurs.length} opération(s) automatique(s)',
                    () => _push(context, const RecurringPage())),
                const SectionTitle('Données'),
                _tile(context, Icons.sync_rounded, tr('Synchronisation'),
                    'Envoyer / recevoir les données entre téléphones',
                    () => _push(context, const SyncPage())),
              ],
              const SizedBox(height: 20),
              Center(
                  child: Text('${app.familyName} · version 1.0.0',
                      style: const TextStyle(color: Colors.grey, fontSize: 12))),
            ],
          ),
        );
      },
    );
  }
}

void _push(BuildContext c, Widget w) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => w));

Future<String?> _askPin(BuildContext c) {
  final ctl = TextEditingController();
  return showDialog<String>(
    context: c,
    builder: (d) => AlertDialog(
      title: const Text('Code PIN à 4 chiffres'),
      content: TextField(
        controller: ctl,
        autofocus: true,
        obscureText: true,
        maxLength: 4,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: deco(d, 'Laisser vide pour supprimer le code'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            if (ctl.text.isEmpty || ctl.text.length == 4) Navigator.pop(d, ctl.text);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

// =====================================================================
// Membres
// =====================================================================
class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  Future<void> _edit(BuildContext c, [M? m]) async {
    final name = TextEditingController(text: m?.s('name') ?? '');
    final pin = TextEditingController(text: m?.s('pin') ?? '');
    var role = m?.s('role') ?? 'child';
    var color = m?.i('color') ?? palette[app.members.length % palette.length];
    await showDialog(
      context: c,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(m == null ? 'Nouveau membre' : 'Modifier le membre'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: deco(d, tr('Nom'))),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'parent', label: Text(tr('Parent'))),
                  ButtonSegment(value: 'child', label: Text(tr('Enfant'))),
                ],
                selected: {role},
                onSelectionChanged: (s) => set(() => role = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pin,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: deco(d, 'Code PIN (facultatif)'),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in palette)
                  GestureDetector(
                    onTap: () => set(() => color = p),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(p),
                      child: color == p
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            if (m != null && m.s('id') != app.meId)
              TextButton(
                onPressed: () async {
                  Navigator.pop(d);
                  await app.del('members', m.s('id'));
                },
                child: const Text('Supprimer'),
              ),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(d);
                await app.save('members', {
                  'id': m?.s('id') ?? newId(),
                  'name': name.text.trim(),
                  'role': role,
                  'pin': pin.text.length == 4 ? pin.text : '',
                  'color': color,
                });
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: Text(tr('Membres'))),
          floatingActionButton: FloatingActionButton(
              onPressed: () => _edit(context), child: const Icon(Icons.person_add_rounded)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            for (final m in app.members)
              Panel(
                margin: const EdgeInsets.only(bottom: 8),
                onTap: () => _edit(context, m),
                child: Row(children: [
                  Avatar(m.s('name'), Color(m.i('color'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.s('name'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(m.s('role') == 'parent' ? tr('Parent') : tr('Enfant'),
                          style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                    ]),
                  ),
                  if (m.s('pin').isNotEmpty) const Icon(Icons.lock_rounded, size: 18),
                ]),
              ),
          ]),
        ),
      );
}

// =====================================================================
// Sources de revenus (Papa, Maman, Voiture 1, Voiture 2...)
// =====================================================================
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  Future<void> _edit(BuildContext c, [M? s]) async {
    final name = TextEditingController(text: s?.s('name') ?? '');
    var type = s?.s('type') ?? 'vehicle';
    await showDialog(
      context: c,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(s == null ? 'Nouvelle source' : 'Modifier la source'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: deco(d, tr('Nom'), hint: 'Ex : Taxi Toyota')),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'person', label: Text('Personne')),
                ButtonSegment(value: 'vehicle', label: Text('Voiture')),
                ButtonSegment(value: 'other', label: Text('Autre')),
              ],
              selected: {type},
              onSelectionChanged: (x) => set(() => type = x.first),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(d);
                await app.save('sources', {
                  'id': s?.s('id') ?? newId(),
                  'name': name.text.trim(),
                  'type': type,
                  'active': s?.i('active') ?? 1,
                });
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: Text(tr('Sources de revenus'))),
          floatingActionButton: FloatingActionButton(
              onPressed: () => _edit(context), child: const Icon(Icons.add_rounded)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'Touchez une source pour la renommer (ex. « Voiture 1 » devient « Taxi Toyota »). L\'historique est conservé.',
                  style: TextStyle(color: Colors.grey)),
            ),
            for (final s in app.sources)
              Panel(
                margin: const EdgeInsets.only(bottom: 8),
                onTap: () => _edit(context, s),
                child: Row(children: [
                  IconBubble(
                    s.s('type') == 'vehicle'
                        ? Icons.directions_car_rounded
                        : s.s('type') == 'person'
                            ? Icons.person_rounded
                            : Icons.savings_rounded,
                    C.income,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s.s('name'),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: s.i('active') == 1 ? null : Colors.grey)),
                  ),
                  Switch(
                    value: s.i('active') == 1,
                    onChanged: (v) => app.save('sources', {...s, 'active': v ? 1 : 0}),
                  ),
                ]),
              ),
          ]),
        ),
      );
}

// =====================================================================
// Categories et sous-categories
// =====================================================================
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  Future<void> _newTop(BuildContext c) async {
    final name = TextEditingController();
    var icon = 'other';
    var color = palette[0];
    await showDialog(
      context: c,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Nouvelle catégorie'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: deco(d, tr('Nom'))),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in iconMap.entries)
                  GestureDetector(
                    onTap: () => set(() => icon = e.key),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: icon == e.key
                          ? Color(color)
                          : Colors.grey.withOpacity(0.2),
                      child: Icon(e.value,
                          size: 18, color: icon == e.key ? Colors.white : Colors.grey),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in palette)
                  GestureDetector(
                    onTap: () => set(() => color = p),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(p),
                      child: color == p
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(d);
                await app.save('categories', {
                  'id': newId(),
                  'name': name.text.trim(),
                  'parent_id': null,
                  'icon': icon,
                  'color': color,
                });
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: Text(tr('Catégories'))),
          floatingActionButton: FloatingActionButton(
              onPressed: () => _newTop(context), child: const Icon(Icons.add_rounded)),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 90), children: [
            for (final c in app.topCats)
              Panel(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: IconBubble(ic(c.s('icon')), Color(c.i('color')), size: 38),
                    title: Text(c.s('name'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${app.subsOf(c.s('id')).length} sous-catégorie(s)'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
                    children: [
                      for (final s in app.subsOf(c.s('id')))
                        ListTile(
                          dense: true,
                          title: Text(s.s('name')),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              onPressed: () async {
                                final n = await askText(context, 'Renommer', initial: s.s('name'));
                                if (n != null && n.isNotEmpty) {
                                  app.save('categories', {...s, 'name': n});
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              onPressed: () async {
                                if (await confirm(context,
                                    'Supprimer « ${s.s('name')} » ? Les anciennes opérations gardent leur montant.')) {
                                  app.del('categories', s.s('id'));
                                }
                              },
                            ),
                          ]),
                        ),
                      Row(children: [
                        TextButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Sous-catégorie'),
                          onPressed: () async {
                            final n = await askText(context, 'Nouvelle sous-catégorie');
                            if (n != null && n.isNotEmpty) {
                              app.save('categories', {
                                'id': newId(),
                                'name': n,
                                'parent_id': c.s('id'),
                                'icon': c.s('icon'),
                                'color': c.i('color'),
                              });
                            }
                          },
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final n = await askText(context, 'Renommer la catégorie',
                                initial: c.s('name'));
                            if (n != null && n.isNotEmpty) app.save('categories', {...c, 'name': n});
                          },
                          child: const Text('Renommer'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
          ]),
        ),
      );
}

// =====================================================================
// Comptes et transferts
// =====================================================================
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  Future<void> _edit(BuildContext c, [M? a]) async {
    final name = TextEditingController(text: a?.s('name') ?? '');
    final init = TextEditingController(text: (a?.i('initial') ?? 0).toString());
    await showDialog(
      context: c,
      builder: (d) => AlertDialog(
        title: Text(a == null ? 'Nouveau compte' : 'Modifier le compte'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: deco(d, tr('Nom'))),
          const SizedBox(height: 12),
          TextField(
            controller: init,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: deco(d, 'Solde de départ', suffix: 'Ar'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(d);
              await app.save('accounts', {
                'id': a?.s('id') ?? newId(),
                'name': name.text.trim(),
                'type': a?.s('type') ?? 'other',
                'initial': int.tryParse(init.text) ?? 0,
              });
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _transfer(BuildContext c) async {
    if (app.accounts.length < 2) return;
    String from = app.accounts[0].s('id'), to = app.accounts[1].s('id');
    final amt = TextEditingController();
    await showDialog(
      context: c,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(tr('Transfert')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: from,
              decoration: deco(d, 'De'),
              items: [for (final a in app.accounts) DropdownMenuItem(value: a.s('id'), child: Text(a.s('name')))],
              onChanged: (v) => set(() => from = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: to,
              decoration: deco(d, 'Vers'),
              items: [for (final a in app.accounts) DropdownMenuItem(value: a.s('id'), child: Text(a.s('name')))],
              onChanged: (v) => set(() => to = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amt,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: deco(d, tr('Montant'), suffix: 'Ar'),
            ),
            const SizedBox(height: 8),
            const Text('Un transfert (ex. retrait MVola) n\'est ni un revenu ni une dépense.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final v = int.tryParse(amt.text) ?? 0;
                if (v <= 0 || from == to) return;
                Navigator.pop(d);
                await app.save('transfers', {
                  'id': newId(),
                  'from_id': from,
                  'to_id': to,
                  'amount': v,
                  'date': dayKey(DateTime.now()),
                });
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: Text(tr('Comptes')), actions: [
            IconButton(
                tooltip: tr('Transfert'),
                onPressed: () => _transfer(context),
                icon: const Icon(Icons.swap_horiz_rounded)),
          ]),
          floatingActionButton: FloatingActionButton(
              onPressed: () => _edit(context), child: const Icon(Icons.add_rounded)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Panel(
              color: C.rice,
              child: Row(children: [
                const Expanded(
                    child: Text('Total tous comptes',
                        style: TextStyle(color: Colors.white70, fontSize: 15))),
                Text(ar(app.totalBalance),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ]),
            ),
            for (final a in app.accounts)
              Panel(
                margin: const EdgeInsets.only(bottom: 8),
                onTap: () => _edit(context, a),
                child: Row(children: [
                  const IconBubble(Icons.account_balance_wallet_rounded, C.rice),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(a.s('name'), style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text(ar(app.balance(a.s('id'))),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
          ]),
        ),
      );
}

// =====================================================================
// Operations recurrentes
// =====================================================================
class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: Text(tr('Récurrents'))),
          body: app.recurs.isEmpty
              ? Center(
                  child: emptyState(
                      'Aucune opération automatique.\nActivez « Répéter chaque mois » lors d\'une saisie (loyer, salaire…).',
                      Icons.repeat_rounded))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final r in app.recurs)
                    Panel(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        IconBubble(
                            r.s('type') == 'in' ? Icons.north_east_rounded : Icons.south_west_rounded,
                            r.s('type') == 'in' ? C.income : C.expense),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                                r.s('type') == 'in'
                                    ? (app.srcById(r.n('source_id'))?.s('name') ?? 'Revenu')
                                    : app.catFull(r.n('category_id')),
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('${ar(r.i('amount'))} · le ${r.i('day')} de chaque mois',
                                style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                          ]),
                        ),
                        Switch(
                            value: r.i('active') == 1,
                            onChanged: (v) => app.save('recurrings', {...r, 'active': v ? 1 : 0})),
                        IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              if (await confirm(context, 'Supprimer cette opération automatique ?')) {
                                app.del('recurrings', r.s('id'));
                              }
                            }),
                      ]),
                    ),
                ]),
        ),
      );
}

// =====================================================================
// Synchronisation par fichier + sauvegarde
// =====================================================================
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});
  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  bool busy = false;

  Future<void> _export() async {
    setState(() => busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final f = File('${dir.path}/famille_budget_$stamp.json');
      await f.writeAsString(await app.exportJson());
      await Share.shareXFiles([XFile(f.path)], text: 'Données ${app.familyName}');
    } catch (e) {
      if (mounted) snack(context, 'Erreur : $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _import() async {
    final f = await openFile();
    if (f == null) return;
    setState(() => busy = true);
    try {
      final n = await app.importJson(await f.readAsString());
      if (mounted) snack(context, '$n élément(s) mis à jour');
    } catch (e) {
      if (mounted) snack(context, 'Fichier invalide');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Synchronisation'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
          child: const Text(
            'Chaque téléphone garde ses données. Pour partager les opérations :\n\n'
            '1. Sur le téléphone qui a de nouvelles données, appuyez sur « Envoyer mes données » et choisissez WhatsApp.\n'
            '2. Sur l\'autre téléphone, ouvrez le fichier reçu puis appuyez sur « Recevoir des données ».\n\n'
            'Les deux téléphones sont fusionnés sans doublon : la modification la plus récente l\'emporte. '
            'Ce fichier sert aussi de sauvegarde complète.',
            style: TextStyle(height: 1.4),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: busy ? null : _export,
          icon: const Icon(Icons.upload_rounded),
          label: const Text('Envoyer mes données'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: busy ? null : _import,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Recevoir des données'),
        ),
        if (busy) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}
