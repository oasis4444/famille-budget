import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'forms.dart';
import 'ops.dart';
import 'reports.dart';
import 'settings.dart';
import 'store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  store = Store();
  await store.init();
  runApp(const FamilleBudgetApp());
}

class FamilleBudgetApp extends StatelessWidget {
  const FamilleBudgetApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => MaterialApp(
          title: 'Famille Budget',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: store.themeMode,
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: store.me == null ? const ProfileScreen() : Shell(key: ValueKey(store.meId)),
        ),
      );
}

// ================================================================ choix du profil + PIN
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _enter(BuildContext c, Rec m) async {
    final pin = m.str('pin') ?? '';
    if (pin.isNotEmpty) {
      final v = await askText(c, 'Code PIN de ${m.name}', kb: TextInputType.number, obscure: true, maxLen: 4);
      if (v == null) return;
      if (v != pin) {
        if (c.mounted) snack(c, 'Code PIN incorrect');
        return;
      }
    }
    store.login(m.id);
  }

  @override
  Widget build(BuildContext context) {
    final ms = store.list('member');
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [kGreen, kGreenLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(color: kYlang, shape: BoxShape.circle),
              child: const Icon(Icons.savings_rounded, size: 44, color: kGreen),
            ),
            const SizedBox(height: 16),
            Text(store.household, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Qui utilise l’application ?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(20),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  for (final m in ms)
                    InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () => _enter(context, m),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white24)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: Color((m.data['color'] as int?) ?? kMemberColors[0]),
                            child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(height: 10),
                          Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(m.str('role') == 'parent' ? 'Parent' : 'Enfant', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            if ((m.str('pin') ?? '').isNotEmpty) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.lock, size: 12, color: Colors.white70)),
                          ]),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => importFlow(context),
              icon: const Icon(Icons.download, color: Colors.white70),
              label: const Text('Importer un fichier de données', style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

// ================================================================ coque + navigation
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), OpsScreen(), ReportsScreen(), SettingsScreen()];
    return Scaffold(
      body: pages[i],
      floatingActionButton: i < 2
          ? FloatingActionButton.extended(
              onPressed: () => openTxn(context),
              backgroundColor: kYlang,
              foregroundColor: kGreen,
              icon: const Icon(Icons.add),
              label: Text(tr('Ajouter'), style: const TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: tr('Accueil')),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: tr('Opérations')),
          NavigationDestination(icon: const Icon(Icons.pie_chart_outline), selectedIcon: const Icon(Icons.pie_chart), label: tr('Bilans')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: tr('Réglages')),
        ],
      ),
    );
  }
}

// ================================================================ accueil
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _pill(String l, double v, IconData i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Icon(i, color: kYlang),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              FittedBox(child: Text(money(v), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final me = store.me!;
        final now = DateTime.now();
        final today = store.between(DateTime(now.year, now.month, now.day), DateTime(now.year, now.month, now.day + 1));
        final all = store.txns();
        final bal = store.isParent ? store.totalBalance : store.sumOf(all, 'income') - store.sumOf(all, 'expense');
        final recent = ([...all]..sort((a, b) {
              final c = b.date.compareTo(a.date);
              return c != 0 ? c : b.u.compareTo(a.u);
            }))
            .take(8)
            .toList();
        final favs = store.list('fav').where((f) => f.str('memberId') == store.meId).toList();
        return ListView(padding: EdgeInsets.zero, children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [kGreen, kGreenLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(backgroundColor: Color((me.data['color'] as int?) ?? kMemberColors[0]), child: Text(me.name.isEmpty ? '?' : me.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                const SizedBox(width: 10),
                Expanded(child: Text('Bonjour, ${me.name}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
                Text(store.household, style: const TextStyle(color: kYlang, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 22),
              Text(store.isParent ? 'Solde du foyer' : 'Mon solde', style: const TextStyle(color: Colors.white70)),
              FittedBox(child: Text(money(bal), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900))),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _pill('${tr('Revenus')} · aujourd’hui', store.sumOf(today, 'income'), Icons.south_west_rounded)),
                const SizedBox(width: 10),
                Expanded(child: _pill('${tr('Dépenses')} · aujourd’hui', store.sumOf(today, 'expense'), Icons.north_east_rounded)),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (favs.isNotEmpty) ...[
                const SectionTitle('Favoris'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final f in favs)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onLongPress: () async {
                            if (await confirm(context, 'Retirer ce favori ?')) store.remove(f.id);
                          },
                          child: ActionChip(
                            avatar: Icon(catIcon(f.str('catId')), size: 18, color: kLaterite),
                            label: Text('${store.subName(f.str('catId'), f.str('subId')).isEmpty ? store.nameOf(f.str('catId')) : store.subName(f.str('catId'), f.str('subId'))} · ${money(f.dbl('amount'))}'),
                            onPressed: () => openTxn(context, preset: {...f.data, 'type': 'expense'}),
                          ),
                        ),
                      ),
                  ]),
                ),
              ],
              if (store.isParent) ...[
                SectionTitle(tr('Comptes')),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final a in store.list('account'))
                      Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF182620) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const CircleAvatar(radius: 4, backgroundColor: kYlang),
                            const SizedBox(width: 6),
                            Expanded(child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor))),
                          ]),
                          const SizedBox(height: 4),
                          FittedBox(child: Text(money(store.balance(a.id)), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                        ]),
                      ),
                  ]),
                ),
              ],
              const SectionTitle('Derniers mouvements'),
              if (recent.isEmpty)
                const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Aucune opération.\nAppuyez sur « Ajouter » pour commencer.', textAlign: TextAlign.center))),
              for (final t in recent) TxnTile(t, onTap: () => openTxn(context, edit: t)),
            ]),
          ),
        ]);
      },
    );
  }
}
