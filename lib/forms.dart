import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'store.dart';
import 'ui.dart';

class TxnForm extends StatefulWidget {
  final Rec? edit;
  final J? preset;
  const TxnForm({super.key, this.edit, this.preset});
  @override
  State<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends State<TxnForm> {
  String type = 'expense';
  final amount = TextEditingController();
  final note = TextEditingController();
  final focus = FocusNode();
  DateTime date = DateTime.now();
  String? catId, subId, srcId, carId, accId, toAccId, memberId;
  bool fav = false, recurring = false;
  int recDay = math.min(28, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    final J p = e?.data ?? widget.preset ?? {};
    type = (p['type'] as String?) ?? 'expense';
    if (p['amount'] != null) amount.text = (p['amount'] as num).toStringAsFixed(0);
    note.text = (p['note'] as String?) ?? '';
    if (e != null) date = e.date;
    catId = p['catId'] as String?;
    subId = p['subId'] as String?;
    srcId = p['sourceId'] as String?;
    carId = p['carId'] as String?;
    final accs = store.list('account');
    accId = (p['accountId'] as String?) ?? (accs.isNotEmpty ? accs.first.id : null);
    toAccId = p['toAccountId'] as String?;
    memberId = store.isParent ? ((p['memberId'] as String?) ?? store.meId) : store.meId;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    focus.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> _entries(String kind, {bool activeOnly = true, bool carsOnly = false}) => [
        for (final r in store.list(kind))
          if ((!activeOnly || r.flag('active', true)) && (!carsOnly || r.flag('car')))
            MapEntry(r.id, r.name)
      ];

  Future<void> _pickCat() async {
    final r = await pickOne(context, tr('Catégorie'), _entries('category'),
        selected: catId,
        newLabel: 'Nouvelle catégorie',
        onNew: () async {
          final n = await askText(context, 'Nouvelle catégorie');
          if (n == null || n.isEmpty) return null;
          return store.addCategory(n);
        });
    if (r != null) setState(() {
      if (r != catId) subId = null;
      catId = r;
    });
  }

  Future<void> _pickSub() async {
    if (catId == null) {
      snack(context, 'Choisissez d’abord une catégorie');
      return;
    }
    final items = [for (final s in store.subsOf(catId, activeOnly: true)) MapEntry(s['id'] as String, s['name'] as String)];
    final r = await pickOne(context, tr('Sous-catégorie'), items,
        selected: subId,
        newLabel: 'Nouvelle sous-catégorie',
        onNew: () async {
          final n = await askText(context, 'Nouvelle sous-catégorie');
          if (n == null || n.isEmpty) return null;
          return store.addSub(catId!, n);
        });
    if (r != null) setState(() => subId = r);
  }

  Future<void> _pickSrc() async {
    final r = await pickOne(context, 'Source du revenu', _entries('source'),
        selected: srcId,
        newLabel: 'Nouvelle source',
        onNew: () async {
          final n = await askText(context, 'Nouvelle source');
          if (n == null || n.isEmpty) return null;
          return store.addSource(n);
        });
    if (r != null) setState(() => srcId = r);
  }

  Future<void> _pickAcc(bool to) async {
    final r = await pickOne(context, tr('Comptes'), _entries('account', activeOnly: false), selected: to ? toAccId : accId);
    if (r != null) setState(() => to ? toAccId = r : accId = r);
  }

  Future<void> _pickCar() async {
    final items = [const MapEntry('', 'Aucune'), ..._entries('source', carsOnly: true)];
    final r = await pickOne(context, 'Voiture concernée', items, selected: carId ?? '');
    if (r != null) setState(() => carId = r.isEmpty ? null : r);
  }

  Future<void> _pickMember() async {
    final r = await pickOne(context, tr('Membres'), _entries('member', activeOnly: false), selected: memberId);
    if (r != null) setState(() => memberId = r);
  }

  Future<bool> _save({bool again = false}) async {
    final a = double.tryParse(amount.text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'));
    if (a == null || a <= 0) {
      snack(context, 'Entrez un montant valide');
      return false;
    }
    if (type == 'expense' && catId == null) {
      snack(context, 'Choisissez une catégorie');
      return false;
    }
    if (type == 'income' && srcId == null) {
      snack(context, 'Choisissez une source de revenu');
      return false;
    }
    if (type == 'transfer' && (toAccId == null || toAccId == accId)) {
      snack(context, 'Choisissez deux comptes différents');
      return false;
    }
    final d = <String, dynamic>{
      'type': type,
      'amount': a,
      'date': DateTime(date.year, date.month, date.day, 12).millisecondsSinceEpoch,
      'memberId': memberId,
      'accountId': accId,
      'note': note.text.trim(),
      if (type == 'expense') ...{'catId': catId, 'subId': subId, if (carId != null) 'carId': carId},
      if (type == 'income') 'sourceId': srcId,
      if (type == 'transfer') 'toAccountId': toAccId,
    };
    await store.put('txn', d, id: widget.edit?.id);
    if (fav && type == 'expense') {
      await store.put('fav', {'catId': catId, 'subId': subId, 'amount': a, 'memberId': store.meId});
    }
    if (recurring && widget.edit == null && type != 'transfer') {
      final tmpl = Map<String, dynamic>.from(d)..remove('date');
      await store.addRecurring(tmpl, recDay);
    }
    if (!mounted) return true;
    if (again) {
      setState(() {
        amount.clear();
        note.clear();
        subId = null;
        fav = false;
      });
      focus.requestFocus();
      snack(context, 'Enregistré ✓ — article suivant');
    } else {
      Navigator.pop(context);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;
    final color = type == 'income' ? kIncome : type == 'expense' ? kLaterite : Colors.blueGrey;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier l’opération' : 'Nouvelle opération'),
        actions: [
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, 'Supprimer cette opération ?')) {
                  await store.remove(widget.edit!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'expense', label: Text(tr('Dépense'))),
            ButtonSegment(value: 'income', label: Text(tr('Revenu'))),
            ButtonSegment(value: 'transfer', label: Text(tr('Transfert'))),
          ],
          selected: {type},
          onSelectionChanged: (s) => setState(() => type = s.first),
        ),
        const SizedBox(height: 16),
        Panel(
          child: TextField(
            controller: amount,
            focusNode: focus,
            autofocus: !editing,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: color),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '0',
              suffixText: 'Ar',
              suffixStyle: TextStyle(fontSize: 18, color: color),
            ),
          ),
        ),
        if (type == 'expense') ...[
          PickTile(icon: Icons.category_outlined, label: tr('Catégorie'), value: catId == null ? 'Choisir…' : store.nameOf(catId), onTap: _pickCat),
          PickTile(
              icon: Icons.label_outline,
              label: tr('Sous-catégorie'),
              value: subId == null ? 'Choisir…' : store.subName(catId, subId),
              onTap: _pickSub),
        ],
        if (type == 'income')
          PickTile(icon: Icons.south_west_rounded, label: 'Source', value: srcId == null ? 'Choisir…' : store.nameOf(srcId), onTap: _pickSrc),
        PickTile(
            icon: Icons.account_balance_wallet_outlined,
            label: type == 'transfer' ? 'Depuis le compte' : 'Compte',
            value: store.nameOf(accId),
            onTap: () => _pickAcc(false)),
        if (type == 'transfer')
          PickTile(icon: Icons.arrow_forward, label: 'Vers le compte', value: toAccId == null ? 'Choisir…' : store.nameOf(toAccId), onTap: () => _pickAcc(true)),
        PickTile(
          icon: Icons.event,
          label: tr('Date'),
          value: dfmt(date, 'EEEE d MMMM yyyy'),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => date = d);
          },
        ),
        if (store.isParent)
          PickTile(icon: Icons.person_outline, label: 'Membre', value: store.nameOf(memberId), onTap: _pickMember),
        if (type == 'expense' && store.list('source').any((s) => s.flag('car') && s.flag('active', true)))
          PickTile(icon: Icons.directions_car_outlined, label: 'Voiture concernée (facultatif)', value: carId == null ? 'Aucune' : store.nameOf(carId), onTap: _pickCar),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: note,
            decoration: InputDecoration(border: InputBorder.none, icon: const Icon(Icons.notes), labelText: tr('Note')),
          ),
        ),
        if (type == 'expense')
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ajouter aux favoris (accès rapide)'),
            value: fav,
            onChanged: (v) => setState(() => fav = v),
          ),
        if (!editing && type != 'transfer')
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Répéter chaque mois'),
            subtitle: recurring ? Text('Le $recDay de chaque mois, dès le mois prochain') : null,
            value: recurring,
            onChanged: (v) => setState(() => recurring = v),
          ),
        if (recurring && !editing)
          Slider(
            min: 1,
            max: 28,
            divisions: 27,
            label: '$recDay',
            value: recDay.toDouble(),
            onChanged: (v) => setState(() => recDay = v.round()),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 58,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            onPressed: () => _save(),
            child: Text(tr('Enregistrer'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ),
        if (!editing && type == 'expense') ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.playlist_add),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              onPressed: () => _save(again: true),
              label: const Text('Enregistrer et ajouter un autre article'),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

void openTxn(BuildContext c, {Rec? edit, J? preset}) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => TxnForm(edit: edit, preset: preset)));
