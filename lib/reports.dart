import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'forms.dart';
import 'store.dart';
import 'ui.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late final TabController tc = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));
  DateTime anchor = DateTime.now();
  String? member;

  int get tab => tc.index;

  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  List<DateTime> get range {
    final a = anchor;
    switch (tab) {
      case 0:
        return [DateTime(a.year, a.month, a.day), DateTime(a.year, a.month, a.day + 1)];
      case 1:
        return [DateTime(a.year, a.month, 1), DateTime(a.year, a.month + 1, 1)];
      default:
        return [DateTime(a.year, 1, 1), DateTime(a.year + 1, 1, 1)];
    }
  }

  String get label => tab == 0 ? dfmt(anchor, 'EEEE d MMMM yyyy') : tab == 1 ? dfmt(anchor, 'MMMM yyyy') : '${anchor.year}';

  void shift(int k) => setState(() {
        switch (tab) {
          case 0:
            anchor = DateTime(anchor.year, anchor.month, anchor.day + k);
            break;
          case 1:
            anchor = DateTime(anchor.year, anchor.month + k, 1);
            break;
          default:
            anchor = DateTime(anchor.year + k, anchor.month, 1);
        }
      });

  // ------------------------------------------------------------ utilitaires
  Map<String, double> _group(Iterable<Rec> ts, String type, String Function(Rec) key) {
    final m = <String, double>{};
    for (final t in ts.where((t) => t.str('type') == type)) {
      final k = key(t);
      m[k] = (m[k] ?? 0) + t.dbl('amount');
    }
    return m;
  }

  List<MapEntry<String, double>> _sorted(Map<String, double> m) => m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  Widget _summary(double inc, double exp) => Panel(
        color: kGreen,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Solde'), style: const TextStyle(color: Colors.white70)),
          Text(money(inc - exp), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _pill(tr('Revenus'), inc, Icons.south_west_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _pill(tr('Dépenses'), exp, Icons.north_east_rounded)),
          ]),
        ]),
      );

  Widget _pill(String l, double v, IconData i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(i, color: kYlang, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              FittedBox(child: Text(money(v), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
            ]),
          ),
        ]),
      );

  Widget _varRow(String l, double cur, double prev, {bool goodUp = true}) {
    final d = cur - prev;
    final good = goodUp ? d >= 0 : d <= 0;
    final pct = prev != 0 ? ' (${d >= 0 ? '+' : ''}${(d / prev.abs() * 100).toStringAsFixed(0)} %)' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(l)),
        Text('${d >= 0 ? '+' : '−'}${money(d.abs())}$pct',
            style: TextStyle(fontWeight: FontWeight.w700, color: d == 0 ? null : good ? kIncome : kLaterite)),
      ]),
    );
  }

  Widget _barRow(String l, double v, double total, Color c) {
    final pct = total > 0 ? v / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('${money(v)}  ·  ${(pct * 100).toStringAsFixed(0)} %', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: pct, color: c, backgroundColor: c.withOpacity(.15), minHeight: 6, borderRadius: BorderRadius.circular(6)),
      ]),
    );
  }

  Widget _breakdown(String title, List<MapEntry<String, double>> e, Color c, {bool palette = false}) {
    final total = e.fold(0.0, (s, x) => s + x.value);
    if (e.isEmpty) return const SizedBox.shrink();
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (var i = 0; i < e.length; i++) _barRow(store.nameOf(e[i].key), e[i].value, total, palette ? kPalette[i % kPalette.length] : c),
      ]),
    );
  }

  Widget _barChart(List<List<double>> series, List<Color> colors, String Function(int) lab, {int every = 1, double width = 8, double height = 170}) {
    final n = series.first.length;
    return SizedBox(
      height: height,
      child: BarChart(BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) => (v.toInt() % every == 0)
                  ? Padding(padding: const EdgeInsets.only(top: 4), child: Text(lab(v.toInt()), style: const TextStyle(fontSize: 10)))
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < n; i++)
            BarChartGroupData(x: i, barsSpace: 2, barRods: [
              for (var s = 0; s < series.length; s++)
                BarChartRodData(toY: series[s][i], color: colors[s], width: width, borderRadius: BorderRadius.circular(3)),
            ]),
        ],
      )),
    );
  }

  // ------------------------------------------------------------ vues
  List<Widget> _day(List<Rec> ts, String? mem) {
    final inc = store.sumOf(ts, 'income'), exp = store.sumOf(ts, 'expense');
    final l = [...ts]..sort((a, b) => b.u.compareTo(a.u));
    return [
      _summary(inc, exp),
      if (store.isParent && mem == null) _memberPanel(ts),
      SectionTitle('Opérations du jour (${l.length})'),
      if (l.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune opération ce jour'))),
      for (final t in l) TxnTile(t, onTap: () => openTxn(context, edit: t)),
    ];
  }

  Widget _memberPanel(List<Rec> ts, {String title = 'Par membre'}) {
    final rows = <Widget>[];
    for (final m in store.list('member')) {
      final mt = ts.where((t) => t.str('memberId') == m.id).toList();
      final i = store.sumOf(mt, 'income'), e = store.sumOf(mt, 'expense');
      if (i == 0 && e == 0) continue;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          CircleAvatar(radius: 14, backgroundColor: Color((m.data['color'] as int?) ?? kMemberColors[0]), child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('+${money(i)}', style: const TextStyle(color: kIncome, fontSize: 12)),
            Text('−${money(e)}', style: const TextStyle(color: kLaterite, fontSize: 12)),
          ]),
        ]),
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), ...rows]));
  }

  Widget _carPanel(List<Rec> ts) {
    final rows = <Widget>[];
    for (final s in store.list('source').where((s) => s.flag('car'))) {
      final rev = ts.where((t) => t.str('type') == 'income' && t.str('sourceId') == s.id).fold(0.0, (a, t) => a + t.dbl('amount'));
      final fr = ts.where((t) => t.str('type') == 'expense' && t.str('carId') == s.id).fold(0.0, (a, t) => a + t.dbl('amount'));
      if (rev == 0 && fr == 0) continue;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const Icon(Icons.directions_car, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Recettes ${money(rev)}  ·  Frais ${money(fr)}', style: const TextStyle(fontSize: 11)),
            Text('Gain net ${money(rev - fr)}', style: TextStyle(fontWeight: FontWeight.w800, color: rev - fr >= 0 ? kIncome : kLaterite)),
          ]),
        ]),
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Gain net par voiture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), ...rows]));
  }

  List<Widget> _month(List<Rec> ts, String? mem) {
    final inc = store.sumOf(ts, 'income'), exp = store.sumOf(ts, 'expense');
    final pr = store.between(DateTime(anchor.year, anchor.month - 1, 1), DateTime(anchor.year, anchor.month, 1), member: mem);
    final pInc = store.sumOf(pr, 'income'), pExp = store.sumOf(pr, 'expense');
    final byCat = _sorted(_group(ts, 'expense', (t) => t.str('catId') ?? '?'));
    final bySub = _sorted(_group(ts, 'expense', (t) {
      final s = store.subName(t.str('catId'), t.str('subId'));
      return '${t.str('catId')}|${t.str('subId')}|${s.isEmpty ? store.nameOf(t.str('catId')) : s}';
    })).take(5).toList();
    final days = DateTime(anchor.year, anchor.month + 1, 0).day;
    final daily = List<double>.filled(days, 0);
    for (final t in ts.where((t) => t.str('type') == 'expense')) {
      daily[t.date.day - 1] += t.dbl('amount');
    }
    final bySrc = _sorted(_group(ts, 'income', (t) => t.str('sourceId') ?? '?'));
    final w = <Widget>[
      _summary(inc, exp),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Par rapport au mois précédent', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          _varRow(tr('Solde'), inc - exp, pInc - pExp),
          _varRow(tr('Revenus'), inc, pInc),
          _varRow(tr('Dépenses'), exp, pExp, goodUp: false),
        ]),
      ),
    ];
    if (byCat.isNotEmpty) {
      w.add(Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Dépenses par catégorie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: [
                for (var i = 0; i < byCat.length; i++)
                  PieChartSectionData(value: byCat[i].value, color: kPalette[i % kPalette.length], radius: 40, showTitle: false),
              ],
            )),
          ),
          for (var i = 0; i < byCat.length; i++)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 8, backgroundColor: kPalette[i % kPalette.length]),
                title: Text(store.nameOf(byCat[i].key), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text('${money(byCat[i].value)} · ${(byCat[i].value / exp * 100).toStringAsFixed(0)} %', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                children: [
                  for (final s in _sorted(_group(ts.where((t) => t.str('catId') == byCat[i].key), 'expense', (t) {
                    final n = store.subName(t.str('catId'), t.str('subId'));
                    return n.isEmpty ? '(sans sous-catégorie)' : n;
                  })))
                    Padding(
                      padding: const EdgeInsets.only(left: 28, bottom: 6),
                      child: Row(children: [Expanded(child: Text(s.key)), Text(money(s.value))]),
                    ),
                ],
              ),
            ),
        ]),
      ));
      w.add(Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Top 5 des postes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (var i = 0; i < bySub.length; i++)
            _barRow('${i + 1}. ${bySub[i].key.split('|').last}', bySub[i].value, exp, kPalette[i % kPalette.length]),
        ]),
      ));
      w.add(Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Dépenses jour par jour', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _barChart([daily], [kLaterite], (i) => '${i + 1}', every: 5, width: 5),
        ]),
      ));
    }
    w.add(_breakdown('Revenus par source', bySrc, kIncome));
    w.add(_carPanel(ts));
    if (store.isParent && mem == null) w.add(_memberPanel(ts, title: 'Détail par membre'));
    if (ts.isEmpty) w.add(const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune opération ce mois'))));
    return w;
  }

  List<Widget> _year(List<Rec> ts, String? mem) {
    final y = anchor.year;
    final now = DateTime.now();
    final inc = store.sumOf(ts, 'income'), exp = store.sumOf(ts, 'expense');
    final mi = List<double>.filled(12, 0), me = List<double>.filled(12, 0);
    for (final t in ts) {
      final i = t.date.month - 1;
      if (t.str('type') == 'income') mi[i] += t.dbl('amount');
      if (t.str('type') == 'expense') me[i] += t.dbl('amount');
    }
    final n = y == now.year ? now.month : 12;
    final active = [for (var i = 0; i < n; i++) if (mi[i] + me[i] > 0) i];
    int? best, worst;
    for (final i in active) {
      if (best == null || mi[i] - me[i] > mi[best] - me[best]) best = i;
      if (worst == null || mi[i] - me[i] < mi[worst] - me[worst]) worst = i;
    }
    final pr = store.between(DateTime(y - 1, 1, 1), DateTime(y, 1, 1), member: mem);
    final pInc = store.sumOf(pr, 'income'), pExp = store.sumOf(pr, 'expense');
    String mname(int i) => dfmt(DateTime(y, i + 1, 1), 'MMMM');
    return [
      _summary(inc, exp),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('12 mois', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Row(children: const [
            CircleAvatar(radius: 5, backgroundColor: kIncome),
            SizedBox(width: 6),
            Text('Revenus', style: TextStyle(fontSize: 12)),
            SizedBox(width: 14),
            CircleAvatar(radius: 5, backgroundColor: kLaterite),
            SizedBox(width: 6),
            Text('Dépenses', style: TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          _barChart([mi, me], [kIncome, kLaterite], (i) => dfmt(DateTime(y, i + 1, 1), 'MMM').substring(0, 1).toUpperCase(), width: 7, height: 190),
        ]),
      ),
      Panel(
        child: Column(children: [
          Row(children: const [
            Expanded(flex: 3, child: Text('Mois', style: TextStyle(fontWeight: FontWeight.w800))),
            Expanded(flex: 3, child: Text('Revenus', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            Expanded(flex: 3, child: Text('Dépenses', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            Expanded(flex: 3, child: Text('Solde', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
          ]),
          const Divider(),
          for (var i = 0; i < 12; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(flex: 3, child: Text(mname(i), style: const TextStyle(fontSize: 12))),
                Expanded(flex: 3, child: Text(_short(mi[i]), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: kIncome))),
                Expanded(flex: 3, child: Text(_short(me[i]), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: kLaterite))),
                Expanded(flex: 3, child: Text(_short(mi[i] - me[i]), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
            ),
        ]),
      ),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Moyennes mensuelles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          _kv('Revenus / mois', money(inc / n)),
          _kv('Dépenses / mois', money(exp / n)),
          if (best != null) _kv('Meilleur mois', '${mname(best)} (${money(mi[best] - me[best])})'),
          if (worst != null) _kv('Pire mois', '${mname(worst)} (${money(mi[worst] - me[worst])})'),
        ]),
      ),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Comparaison avec ${y - 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          _varRow(tr('Solde'), inc - exp, pInc - pExp),
          _varRow(tr('Revenus'), inc, pInc),
          _varRow(tr('Dépenses'), exp, pExp, goodUp: false),
        ]),
      ),
      _breakdown('Dépenses par catégorie', _sorted(_group(ts, 'expense', (t) => t.str('catId') ?? '?')), kLaterite, palette: true),
      _breakdown('Revenus par source', _sorted(_group(ts, 'income', (t) => t.str('sourceId') ?? '?')), kIncome),
      _carPanel(ts),
      if (store.isParent && mem == null) _memberPanel(ts, title: 'Détail par membre'),
    ];
  }

  String _short(double v) {
    if (v == 0) return '—';
    final a = v.abs();
    final s = a >= 1000000 ? '${(a / 1000000).toStringAsFixed(1)} M' : a >= 1000 ? '${(a / 1000).toStringAsFixed(0)} k' : a.toStringAsFixed(0);
    return v < 0 ? '−$s' : s;
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(k)), Text(v, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );

  // ------------------------------------------------------------ partage
  String _summaryText(List<Rec> ts) {
    final inc = store.sumOf(ts, 'income'), exp = store.sumOf(ts, 'expense');
    final top = _sorted(_group(ts, 'expense', (t) => t.str('catId') ?? '?')).take(5);
    final sb = StringBuffer('📊 ${store.household}\n$label\n\n');
    sb.writeln('Revenus : ${money(inc)}');
    sb.writeln('Dépenses : ${money(exp)}');
    sb.writeln('Solde : ${money(inc - exp)}');
    if (top.isNotEmpty) {
      sb.writeln('\nPrincipaux postes :');
      for (final e in top) {
        sb.writeln('• ${store.nameOf(e.key)} : ${money(e.value)}');
      }
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final mem = store.isParent ? member : store.meId;
        final r = range;
        final ts = store.between(r[0], r[1], member: mem);
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('Bilans')),
            actions: [
              IconButton(icon: const Icon(Icons.share), tooltip: 'Partager le résumé (WhatsApp)', onPressed: () => Share.share(_summaryText(ts))),
              IconButton(
                icon: const Icon(Icons.table_chart_outlined),
                tooltip: 'Exporter en CSV (Excel)',
                onPressed: () async {
                  final f = await store.csvFile(ts);
                  await Share.shareXFiles([XFile(f.path)], text: 'Export ${store.household} — $label');
                },
              ),
            ],
            bottom: TabBar(controller: tc, tabs: [Tab(text: tr('Jour')), Tab(text: tr('Mois')), Tab(text: tr('Année'))]),
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => shift(-1)),
                Expanded(
                  child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                if (store.isParent)
                  IconButton(
                    icon: Icon(member == null ? Icons.person_outline : Icons.person, color: member == null ? null : kLaterite),
                    tooltip: 'Filtrer par membre',
                    onPressed: () async {
                      final v = await pickOne(context, 'Filtrer par membre', [
                        const MapEntry('', 'Tout le foyer'),
                        for (final m in store.list('member')) MapEntry(m.id, m.name),
                      ], selected: member ?? '');
                      if (v != null) setState(() => member = v.isEmpty ? null : v);
                    },
                  ),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => shift(1)),
              ]),
            ),
            if (store.isParent && member != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Chip(label: Text('Membre : ${store.nameOf(member)}'), onDeleted: () => setState(() => member = null)),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: tab == 0 ? _day(ts, mem) : tab == 1 ? _month(ts, mem) : _year(ts, mem),
              ),
            ),
          ]),
        );
      },
    );
  }
}
