import 'package:flutter/material.dart';
import 'store.dart';
import 'ui.dart';

/// Formulaire d'ajout d'un mouvement manuel de stock de riz
/// (achat hors dépense suivie, consommation, don, perte...).
Future<void> _moveForm(BuildContext context, {required String type}) async {
  final qty = TextEditingController();
  final note = TextEditingController();
  DateTime date = DateTime.now();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 8,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: StatefulBuilder(
        builder: (ctx, set) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            type == 'in' ? 'Entrée de riz (achat, don reçu...)' : 'Sortie de riz (cuisiné, donné, perdu...)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: qty,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: type == 'in' ? kIncome : kLaterite),
            decoration: InputDecoration(border: InputBorder.none, hintText: '0', suffixText: 'kg'),
          ),
          const SizedBox(height: 8),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (facultatif)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(dfmt(date, 'EEEE d MMMM yyyy')),
            onTap: () async {
              final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) set(() => date = d);
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: type == 'in' ? kIncome : kLaterite),
              onPressed: () async {
                final v = double.tryParse(qty.text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'));
                if (v == null || v <= 0) {
                  snack(ctx, 'Entrez une quantité valide');
                  return;
                }
                await store.addRiceMove(type, v, note: note.text.trim(), date: date);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(tr('Enregistrer'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    ),
  );
}

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final stock = store.riceStock;
        final threshold = store.riceThreshold;
        final low = stock <= threshold;
        final moves = store.riceMoves;
        return Scaffold(
          appBar: AppBar(title: Text(tr('Stock de riz'))),
          floatingActionButton: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: 'out',
                onPressed: () => _moveForm(context, type: 'out'),
                backgroundColor: kLaterite,
                icon: const Icon(Icons.remove),
                label: const Text('Sortie'),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.extended(
                heroTag: 'in',
                onPressed: () => _moveForm(context, type: 'in'),
                backgroundColor: kIncome,
                icon: const Icon(Icons.add),
                label: const Text('Entrée'),
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 110), children: [
            Panel(
              color: low ? kLaterite : kRice,
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.grain, color: Colors.white70),
                  const SizedBox(width: 8),
                  const Text('Stock actuel', style: TextStyle(color: Colors.white70)),
                  const Spacer(),
                  if (low)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Stock bas', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 6),
                Text(kg(stock), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Seuil d’alerte : ${kg(threshold)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
            if (store.isParent)
              Panel(
                onTap: () async {
                  final v = await askText(context, 'Seuil d’alerte (kg)',
                      initial: threshold == threshold.roundToDouble() ? threshold.toStringAsFixed(0) : threshold.toStringAsFixed(1),
                      kb: const TextInputType.numberWithOptions(decimal: true));
                  if (v == null || v.isEmpty) return;
                  final d = double.tryParse(v.replaceAll(',', '.'));
                  if (d == null || d < 0) {
                    if (context.mounted) snack(context, 'Valeur invalide');
                    return;
                  }
                  await store.setRiceThreshold(d);
                },
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  const Icon(Icons.tune),
                  const SizedBox(width: 14),
                  const Expanded(child: Text('Modifier le seuil d’alerte', style: TextStyle(fontWeight: FontWeight.w700))),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            const SectionTitle('Historique'),
            if (moves.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Text(
                    'Aucun mouvement.\nAjoutez une entrée lors d’un achat de riz, ou utilisez les boutons ci-dessous.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            for (final m in moves) _MoveTile(m),
          ]),
        );
      },
    );
  }
}

class _MoveTile extends StatelessWidget {
  final Rec m;
  const _MoveTile(this.m);
  @override
  Widget build(BuildContext context) {
    final isIn = m.str('type') == 'in';
    final note = (m.str('note') ?? '').trim();
    final fromTxn = m.data.containsKey('txnId');
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: (isIn ? kIncome : kLaterite).withOpacity(.14),
          child: Icon(isIn ? Icons.add : Icons.remove, color: isIn ? kIncome : kLaterite),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isIn ? 'Entrée' : 'Sortie',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              '${dfmt(m.date, 'd MMM')} · ${store.nameOf(m.str('memberId'))}'
              '${fromTxn ? ' · depuis une dépense' : ''}'
              '${note.isEmpty ? '' : ' · $note'}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ]),
        ),
        Text('${isIn ? '+' : '−'}${kg(m.dbl('qty'))}', style: TextStyle(color: isIn ? kIncome : kLaterite, fontWeight: FontWeight.w800)),
        if (store.isParent)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () async {
              if (await confirm(context, 'Supprimer ce mouvement ?')) store.remove(m.id);
            },
          ),
      ]),
    );
  }
}
