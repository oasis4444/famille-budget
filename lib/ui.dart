import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'store.dart';

// Identité « Rizière »
const kGreen = Color(0xFF1B4D3E);
const kGreenLight = Color(0xFF2F7A5F);
const kLaterite = Color(0xFFC0492B);
const kYlang = Color(0xFFE8B931);
const kIncome = Color(0xFF2E7D5B);

const kPalette = <Color>[
  Color(0xFFC0492B), Color(0xFF1B4D3E), Color(0xFFE8B931), Color(0xFF3F7CAC),
  Color(0xFF8E5BA8), Color(0xFF2A9D8F), Color(0xFFE07A5F), Color(0xFF6D6875),
  Color(0xFF9BC53D), Color(0xFFD4A5A5), Color(0xFF5C6B73), Color(0xFFFF8C42),
];

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final cs = ColorScheme.fromSeed(
    seedColor: kGreen,
    brightness: b,
    primary: dark ? const Color(0xFF7FCBA8) : kGreen,
    secondary: kYlang,
    tertiary: kLaterite,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: dark ? const Color(0xFF0F1A16) : const Color(0xFFF5F3EA),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: kYlang.withOpacity(.35),
      height: 68,
    ),
  );
}

// ---------------------------------------------------------------- formats
final _nf = NumberFormat('#,##0', 'fr');
String money(num v) => '${_nf.format(v.round())} Ar';
String dfmt(DateTime d, [String pattern = 'd MMM yyyy']) =>
    DateFormat(pattern, 'fr').format(d);

// ---------------------------------------------------------------- traduction (FR / MG)
const _mg = <String, String>{
  'Accueil': 'Fandraisana',
  'Opérations': 'Fifanakalozana',
  'Bilans': 'Tatitra',
  'Réglages': 'Fikirakirana',
  'Ajouter': 'Ampiana',
  'Revenus': 'Vola miditra',
  'Revenu': 'Vola miditra',
  'Dépenses': 'Fandaniana',
  'Dépense': 'Fandaniana',
  'Solde': 'Sisa',
  'Enregistrer': 'Tehirizo',
  'Annuler': 'Foano',
  'Jour': 'Andro',
  'Mois': 'Volana',
  'Année': 'Taona',
  'Comptes': 'Kaonty',
  'Membres': 'Mpikambana',
  'Note': 'Fanamarihana',
  'Montant': 'Vola',
  'Date': 'Daty',
  'Transfert': 'Famindrana',
  'Catégorie': 'Sokajy',
  'Catégories': 'Sokajy',
  'Sous-catégorie': 'Sokajy kely',
  'Apparence': 'Endrika',
  'Langue': 'Fiteny',
  'Tout': 'Rehetra',
  'Rechercher': 'Karohy',
  'Changer de profil': 'Hanova mpampiasa',
  'Sauvegarde et partage': 'Fitahirizana sy fizarana',
};
String tr(String s) => store.lang == 'mg' ? (_mg[s] ?? s) : s;

// ---------------------------------------------------------------- widgets
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  @override
  Widget build(BuildContext c) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color ?? (dark ? const Color(0xFF182620) : Colors.white),
        borderRadius: BorderRadius.circular(22),
        boxShadow: dark
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      );
}

class PickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const PickTile({super.key, required this.icon, required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext c) => Panel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: Theme.of(c).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12, color: Theme.of(c).hintColor)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
          ),
          const Icon(Icons.chevron_right),
        ]),
      );
}

const _catIcons = <IconData>[
  Icons.restaurant, Icons.spa, Icons.cleaning_services, Icons.bolt, Icons.key,
  Icons.directions_bus, Icons.medical_services, Icons.school, Icons.phone_android,
  Icons.checkroom, Icons.sports_esports, Icons.volunteer_activism,
  Icons.directions_car, Icons.warning_amber, Icons.more_horiz,
];
IconData catIcon(String? id) {
  if (id != null && id.startsWith('cat_')) {
    final i = int.tryParse(id.substring(4));
    if (i != null && i < _catIcons.length) return _catIcons[i];
  }
  return Icons.label_outline;
}

String txnTitle(Rec t) {
  switch (t.str('type')) {
    case 'income':
      return store.nameOf(t.str('sourceId'));
    case 'transfer':
      return '${store.nameOf(t.str('accountId'))} → ${store.nameOf(t.str('toAccountId'))}';
    default:
      final s = store.subName(t.str('catId'), t.str('subId'));
      return s.isNotEmpty ? s : store.nameOf(t.str('catId'));
  }
}

class TxnTile extends StatelessWidget {
  final Rec t;
  final VoidCallback? onTap;
  const TxnTile(this.t, {super.key, this.onTap});
  @override
  Widget build(BuildContext c) {
    final ty = t.str('type');
    final color = ty == 'income' ? kIncome : ty == 'expense' ? kLaterite : Colors.blueGrey;
    final icon = ty == 'income'
        ? Icons.south_west_rounded
        : ty == 'expense'
            ? catIcon(t.str('catId'))
            : Icons.swap_horiz_rounded;
    final note = (t.str('note') ?? '').trim();
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(children: [
        CircleAvatar(radius: 22, backgroundColor: color.withOpacity(.14), child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(txnTitle(t), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(
              '${dfmt(t.date, 'd MMM')} · ${store.nameOf(t.str('memberId'))} · ${store.nameOf(t.str('accountId'))}${note.isEmpty ? '' : ' · $note'}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Theme.of(c).hintColor),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Text('${ty == 'income' ? '+' : ty == 'expense' ? '−' : ''}${money(t.dbl('amount'))}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- dialogues
void snack(BuildContext c, String msg) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

Future<String?> askText(BuildContext c, String title,
    {String initial = '', String hint = '', TextInputType? kb, bool obscure = false, int? maxLen}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        keyboardType: kb,
        obscureText: obscure,
        maxLength: maxLen,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext c, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Annuler'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
      ],
    ),
  );
  return r ?? false;
}

/// Sélecteur en bas d'écran (gros boutons). onNew permet de créer pendant la saisie.
Future<String?> pickOne(BuildContext c, String title, List<MapEntry<String, String>> items,
    {String? selected, Future<String?> Function()? onNew, String newLabel = 'Nouveau'}) {
  return showModalBottomSheet<String>(
    context: c,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .75),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final e in items)
                ListTile(
                  title: Text(e.value),
                  trailing: selected == e.key ? const Icon(Icons.check_circle, color: kIncome) : null,
                  onTap: () => Navigator.pop(ctx, e.key),
                ),
              if (onNew != null)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: Text(newLabel),
                  onTap: () async {
                    final id = await onNew();
                    if (ctx.mounted) Navigator.pop(ctx, id);
                  },
                ),
            ]),
          ),
        ]),
      ),
    ),
  );
}
