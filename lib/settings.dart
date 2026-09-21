import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'store.dart';
import 'ui.dart';

/// Import d'un fichier de données reçu (WhatsApp, etc.) : fusion sans doublon.
Future<void> importFlow(BuildContext c) async {
  final r = await FilePicker.platform.pickFiles();
  final path = r?.files.single.path;
  if (path == null) return;
  try {
    final n = await store.importFile(path);
    if (c.mounted) snack(c, 'Fusion terminée : $n élément(s) mis à jour ✓');
  } catch (_) {
    if (c.mounted) snack(c, 'Fichier non reconnu');
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _nav(BuildContext c, IconData i, String title, String sub, Widget page) => Panel(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
        child: Row(children: [
          CircleAvatar(backgroundColor: kYlang.withOpacity(.3), child: Icon(i, color: kGreen)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(sub, style: TextStyle(fontSize: 12, color: Theme.of(c).hintColor)),
            ]),
          ),
          const Icon(Icons.chevron_right),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final me = store.me!;
        return Scaffold(
          appBar: AppBar(title: Text(tr('Réglages'))),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Panel(
              child: Row(children: [
                CircleAvatar(radius: 24, backgroundColor: Color((me.data['color'] as int?) ?? kMemberColors[0]), child: Text(me.name.isEmpty ? '?' : me.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(me.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(store.isParent ? 'Parent' : 'Enfant', style: TextStyle(color: Theme.of(context).hintColor)),
                  ]),
                ),
                TextButton.icon(onPressed: store.logout, icon: const Icon(Icons.swap_horiz), label: Text(tr('Changer de profil'))),
              ]),
            ),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Apparence'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'light', label: Text('Clair')),
                    ButtonSegment(value: 'dark', label: Text('Sombre')),
                    ButtonSegment(value: 'auto', label: Text('Auto')),
                  ],
                  selected: {store.themeKey},
                  onSelectionChanged: (s) => store.setLocal('theme', s.first),
                ),
                const SizedBox(height: 14),
                Text(tr('Langue'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'fr', label: Text('Français')),
                    ButtonSegment(value: 'mg', label: Text('Malagasy')),
                  ],
                  selected: {store.lang},
                  onSelectionChanged: (s) => store.setLocal('lang', s.first),
                ),
              ]),
            ),
            if (!store.isParent)
              Panel(
                onTap: () async {
                  final v = await askText(context, 'Mon code PIN (4 chiffres, vide = aucun)', initial: me.str('pin') ?? '', kb: TextInputType.number, maxLen: 4);
                  if (v == null) return;
                  if (v.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(v)) {
                    if (context.mounted) snack(context, 'Le PIN doit avoir 4 chiffres');
                    return;
                  }
                  await store.put('member', {...me.data, 'pin': v}, id: me.id);
                },
                child: const Row(children: [Icon(Icons.lock_outline), SizedBox(width: 14), Text('Mon code PIN', style: TextStyle(fontWeight: FontWeight.w700))]),
              ),
            if (store.isParent) ...[
              Panel(
                onTap: () async {
                  final v = await askText(context, 'Nom du foyer', initial: store.household);
                  if (v != null && v.isNotEmpty) store.setHousehold(v);
                },
                child: Row(children: [
                  const Icon(Icons.home_outlined),
                  const SizedBox(width: 14),
                  Expanded(child: Text(store.household, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  const Icon(Icons.edit_outlined, size: 18),
                ]),
              ),
              _nav(context, Icons.group_outlined, tr('Membres'), 'Parents, enfants, couleurs, codes PIN', const MembersPage()),
              _nav(context, Icons.south_west_rounded, 'Sources de revenus', 'Papa, Maman, voitures…', const SourcesPage()),
              _nav(context, Icons.category_outlined, tr('Catégories'), 'Catégories et sous-catégories de dépenses', const CategoriesPage()),
              _nav(context, Icons.account_balance_wallet_outlined, tr('Comptes'), 'Espèces, MVola, Orange Money, Airtel Money, Banque', const AccountsPage()),
              _nav(context, Icons.repeat, 'Opérations récurrentes', 'Salaire, loyer, abonnements', const RecurringPage()),
              _nav(context, Icons.sync_alt, tr('Sauvegarde et partage'), 'Fusionner les téléphones par fichier', const SyncPage()),
            ],
            const SizedBox(height: 8),
            Center(child: Text('Famille Budget 1.0 · fonctionne sans internet', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))),
          ]),
        );
      },
    );
  }
}

// ================================================================ membres
Future<void> editMember(BuildContext c, Rec? m) async {
  final name = TextEditingController(text: m?.name ?? '');
  final pin = TextEditingController(text: m?.str('pin') ?? '');
  var role = m?.str('role') ?? 'enfant';
  var color = (m?.data['color'] as int?) ?? kMemberColors[store.list('member').length % kMemberColors.length];
  await showDialog(
    context: c,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(m == null ? 'Nouveau membre' : 'Modifier le membre'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'parent', label: Text('Parent')), ButtonSegment(value: 'enfant', label: Text('Enfant'))],
              selected: {role},
              onSelectionChanged: (s) => set(() => role = s.first),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in kMemberColors)
                GestureDetector(
                  onTap: () => set(() => color = k),
                  child: CircleAvatar(radius: 16, backgroundColor: Color(k), child: color == k ? const Icon(Icons.check, color: Colors.white, size: 18) : null),
                ),
            ]),
            TextField(controller: pin, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Code PIN (facultatif)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
          FilledButton(
            onPressed: () async {
              final n = name.text.trim();
              final pn = pin.text.trim();
              if (n.isEmpty) return snack(ctx, 'Entrez un nom');
              if (pn.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(pn)) return snack(ctx, 'Le PIN doit avoir 4 chiffres');
              final parents = store.list('member').where((x) => x.str('role') == 'parent').length;
              if (m != null && m.str('role') == 'parent' && role != 'parent' && parents <= 1) {
                return snack(ctx, 'Il faut au moins un parent');
              }
              await store.put('member', {'name': n, 'role': role, 'color': color, 'pin': pn}, id: m?.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(tr('Enregistrer')),
          ),
        ],
      ),
    ),
  );
}

class MembersPage extends StatelessWidget {
  const MembersPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: Text(tr('Membres'))),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => editMember(context, null), icon: const Icon(Icons.person_add), label: Text(tr('Ajouter'))),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            for (final m in store.list('member'))
              Panel(
                onTap: () => editMember(context, m),
                child: Row(children: [
                  CircleAvatar(backgroundColor: Color((m.data['color'] as int?) ?? kMemberColors[0]), child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(m.str('role') == 'parent' ? 'Parent' : 'Enfant', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                    ]),
                  ),
                  if ((m.str('pin') ?? '').isNotEmpty) const Icon(Icons.lock_outline, size: 18),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final parents = store.list('member').where((x) => x.str('role') == 'parent').length;
                      if (m.id == store.meId) return snack(context, 'Vous ne pouvez pas vous supprimer vous-même');
                      if (m.str('role') == 'parent' && parents <= 1) return snack(context, 'Il faut au moins un parent');
                      if (await confirm(context, 'Supprimer ${m.name} ? Ses opérations sont conservées.')) store.remove(m.id);
                    },
                  ),
                ]),
              ),
          ]),
        ),
      );
}

// ================================================================ sources
Future<void> editSource(BuildContext c, Rec? s) async {
  final name = TextEditingController(text: s?.name ?? '');
  var car = s?.flag('car') ?? false;
  await showDialog(
    context: c,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(s == null ? 'Nouvelle source' : 'Modifier la source'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nom (ex. Taxi Toyota)')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('C’est une voiture'), subtitle: const Text('Active le gain net par voiture'), value: car, onChanged: (v) => set(() => car = v)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              // même id => l'historique est conservé lors d'un renommage
              await store.put('source', {...?s?.data, 'name': name.text.trim(), 'car': car, 'active': s?.flag('active', true) ?? true}, id: s?.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(tr('Enregistrer')),
          ),
        ],
      ),
    ),
  );
}

class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('Sources de revenus')),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => editSource(context, null), icon: const Icon(Icons.add), label: Text(tr('Ajouter'))),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            for (final s in store.list('source'))
              Panel(
                onTap: () => editSource(context, s),
                child: Row(children: [
                  Icon(s.flag('car') ? Icons.directions_car : Icons.south_west_rounded, color: s.flag('active', true) ? kIncome : Colors.grey),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: s.flag('active', true) ? null : Colors.grey)),
                      if (s.flag('car')) Text('Voiture', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                    ]),
                  ),
                  Switch(value: s.flag('active', true), onChanged: (v) => store.put('source', {...s.data, 'active': v}, id: s.id)),
                ]),
              ),
          ]),
        ),
      );
}

// ================================================================ catégories
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  Future<void> _renameSub(BuildContext c, Rec cat, Map s) async {
    final n = await askText(c, 'Renommer', initial: s['name'] as String);
    if (n == null || n.isEmpty) return;
    final subs = [for (final x in cat.data['subs'] as List) (x as Map)['id'] == s['id'] ? {...x, 'name': n} : x];
    store.put('category', {...cat.data, 'subs': subs}, id: cat.id);
  }

  Future<void> _delSub(Rec cat, Map s) async {
    final subs = [for (final x in cat.data['subs'] as List) (x as Map)['id'] == s['id'] ? {...x, 'active': false} : x];
    store.put('category', {...cat.data, 'subs': subs}, id: cat.id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: Text(tr('Catégories'))),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final n = await askText(context, 'Nouvelle catégorie');
              if (n != null && n.isNotEmpty) store.addCategory(n);
            },
            icon: const Icon(Icons.add),
            label: Text(tr('Ajouter')),
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
            for (final cat in store.list('category'))
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Icon(catIcon(cat.id), color: kLaterite),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${store.subsOf(cat.id, activeOnly: true).length} sous-catégories', style: const TextStyle(fontSize: 12)),
                    children: [
                      for (final s in store.subsOf(cat.id, activeOnly: true))
                        ListTile(
                          dense: true,
                          title: Text(s['name'] as String),
                          onTap: () => _renameSub(context, cat, s),
                          trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _delSub(cat, s)),
                        ),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.add),
                        title: const Text('Ajouter une sous-catégorie'),
                        onTap: () async {
                          final n = await askText(context, 'Nouvelle sous-catégorie');
                          if (n != null && n.isNotEmpty) store.addSub(cat.id, n);
                        },
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                          onPressed: () async {
                            final n = await askText(context, 'Renommer la catégorie', initial: cat.name);
                            if (n != null && n.isNotEmpty) store.put('category', {...cat.data, 'name': n}, id: cat.id);
                          },
                          child: const Text('Renommer'),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (await confirm(context, 'Supprimer « ${cat.name} » ? L’historique est conservé.')) store.remove(cat.id);
                          },
                          child: const Text('Supprimer', style: TextStyle(color: kLaterite)),
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

// ================================================================ comptes
Future<void> editAccount(BuildContext c, Rec? a) async {
  final name = TextEditingController(text: a?.name ?? '');
  final open = TextEditingController(text: a == null ? '' : a.dbl('opening').toStringAsFixed(0));
  await showDialog(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(a == null ? 'Nouveau compte' : 'Modifier le compte'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nom')),
        TextField(controller: open, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Solde de départ (Ar)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            final v = double.tryParse(open.text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.')) ?? 0;
            await store.put('account', {'name': name.text.trim(), 'opening': v}, id: a?.id);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(tr('Enregistrer')),
        ),
      ],
    ),
  );
}

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: Text(tr('Comptes'))),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => editAccount(context, null), icon: const Icon(Icons.add), label: Text(tr('Ajouter'))),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            for (final a in store.list('account'))
              Panel(
                onTap: () => editAccount(context, a),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Départ : ${money(a.dbl('opening'))}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                    ]),
                  ),
                  Text(money(store.balance(a.id)), style: const TextStyle(fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (await confirm(context, 'Supprimer le compte « ${a.name} » ?')) store.remove(a.id);
                    },
                  ),
                ]),
              ),
          ]),
        ),
      );
}

// ================================================================ récurrents
class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final l = store.list('recurring');
          return Scaffold(
            appBar: AppBar(title: const Text('Opérations récurrentes')),
            body: l.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Aucune opération récurrente.\nActivez « Répéter chaque mois » lors de la saisie d’un salaire, du loyer ou d’un abonnement.', textAlign: TextAlign.center),
                    ),
                  )
                : ListView(padding: const EdgeInsets.all(16), children: [
                    for (final r in l)
                      Panel(
                        child: Row(children: [
                          const Icon(Icons.repeat),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(txnTitle(Rec('x', 'txn', Map<String, dynamic>.from(r.data['tmpl'] as Map), 0, false)), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              Text('Le ${r.data['day']} de chaque mois · ${money((r.data['tmpl'] as Map)['amount'] as num)}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                            ]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (await confirm(context, 'Arrêter cette opération récurrente ?')) store.remove(r.id);
                            },
                          ),
                        ]),
                      ),
                  ]),
          );
        },
      );
}

// ================================================================ synchronisation
class SyncPage extends StatelessWidget {
  const SyncPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('Sauvegarde et partage'))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Panel(
            child: Text(
              'Pour réunir les données de plusieurs téléphones :\n\n'
              '1. Sur le téléphone A : « Envoyer mes données » → choisissez WhatsApp.\n'
              '2. Sur le téléphone B : ouvrez le fichier reçu, enregistrez-le, puis « Importer un fichier ».\n'
              '3. Faites l’inverse pour que les deux soient identiques.\n\n'
              'Les données sont fusionnées sans doublon ; en cas de modification des deux côtés, la plus récente l’emporte. Ce fichier sert aussi de sauvegarde complète.',
            ),
          ),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Envoyer mes données (WhatsApp)'),
              onPressed: () async {
                final f = await store.exportFile();
                await Share.shareXFiles([XFile(f.path)], text: 'Données Famille Budget');
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Importer un fichier'),
              onPressed: () => importFlow(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Exporter tout en CSV (Excel)'),
              onPressed: () async {
                final f = await store.csvFile(store.txns());
                await Share.shareXFiles([XFile(f.path)]);
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('Bientôt : synchronisation automatique en temps réel (Firebase).', style: TextStyle(color: Theme.of(context).hintColor)),
        ]),
      );
}
