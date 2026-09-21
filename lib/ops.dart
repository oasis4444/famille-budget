import 'package:flutter/material.dart';
import 'forms.dart';
import 'store.dart';
import 'ui.dart';

class OpsScreen extends StatefulWidget {
  const OpsScreen({super.key});
  @override
  State<OpsScreen> createState() => _OpsScreenState();
}

class _OpsScreenState extends State<OpsScreen> {
  String q = '';
  String? type; // income | expense | transfer
  DateTimeRange? range;
  String? member;

  bool _match(Rec t) {
    if (type != null && t.str('type') != type) return false;
    if (member != null && t.str('memberId') != member) return false;
    if (range != null) {
      final d = t.date;
      final end = range!.end.add(const Duration(days: 1));
      if (d.isBefore(range!.start) || !d.isBefore(end)) return false;
    }
    if (q.isNotEmpty) {
      final s = q.toLowerCase();
      final hay = '${txnTitle(t)} ${t.str('note') ?? ''} ${store.nameOf(t.str('catId'))}'.toLowerCase();
      final amt = t.dbl('amount').toStringAsFixed(0);
      if (!hay.contains(s) && !amt.contains(s.replaceAll(' ', ''))) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final l = store.txns().where(_match).toList()
          ..sort((a, b) {
            final c = b.date.compareTo(a.date);
            return c != 0 ? c : b.u.compareTo(a.u);
          });
        final inc = store.sumOf(l, 'income'), exp = store.sumOf(l, 'expense');
        return Scaffold(
          appBar: AppBar(title: Text(tr('Opérations'))),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => q = v.trim()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '${tr('Rechercher')} (mot-clé, montant)',
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                for (final e in {null: tr('Tout'), 'expense': tr('Dépenses'), 'income': tr('Revenus'), 'transfer': 'Transferts'}.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(e.value), selected: type == e.key, onSelected: (_) => setState(() => type = e.key)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(range == null ? 'Période' : '${dfmt(range!.start, 'd MMM')} → ${dfmt(range!.end, 'd MMM')}'),
                  onPressed: () async {
                    final r = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDateRange: range);
                    if (r != null) setState(() => range = r);
                  },
                ),
                if (range != null)
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => range = null)),
                if (store.isParent) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text(member == null ? tr('Membres') : store.nameOf(member)),
                    onPressed: () async {
                      final r = await pickOne(context, tr('Membres'), [
                        const MapEntry('', 'Tous'),
                        for (final m in store.list('member')) MapEntry(m.id, m.name),
                      ], selected: member ?? '');
                      if (r != null) setState(() => member = r.isEmpty ? null : r);
                    },
                  ),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${l.length} opération(s)', style: TextStyle(color: Theme.of(context).hintColor)),
                Text('+${money(inc)}  −${money(exp)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
            Expanded(
              child: l.isEmpty
                  ? const Center(child: Text('Aucune opération'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: l.length,
                      itemBuilder: (_, i) => TxnTile(l[i], onTap: () => openTxn(context, edit: l[i])),
                    ),
            ),
          ]),
        );
      },
    );
  }
}
