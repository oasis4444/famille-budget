import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

typedef J = Map<String, dynamic>;

late Store store;
const _uuid = Uuid();

const kMemberColors = <int>[
  0xFF1B4D3E, 0xFFC0492B, 0xFFE8B931, 0xFF3F7CAC,
  0xFF8E5BA8, 0xFF2A9D8F, 0xFFE07A5F, 0xFF6D6875,
];

/// Un enregistrement générique (membre, source, catégorie, compte, opération...).
/// u = date de modification (ms), d = supprimé (suppression douce, utile pour la fusion).
class Rec {
  final String id, kind;
  J data;
  int u;
  bool d;
  Rec(this.id, this.kind, this.data, this.u, this.d);
  String get name => (data['name'] ?? '') as String;
  String? str(String k) => data[k] as String?;
  double dbl(String k) => ((data[k] ?? 0) as num).toDouble();
  bool flag(String k, [bool def = false]) => (data[k] as bool?) ?? def;
  DateTime get date =>
      DateTime.fromMillisecondsSinceEpoch((data['date'] ?? 0) as int);
}

const _seedCats = <String, List<String>>{
  'Alimentation': ['Riz', 'Légumes', 'Fruits', 'Viande', 'Poisson', 'Œufs', 'Pain et biscuits', 'Huile et condiments', 'Boissons', 'Épicerie diverse'],
  'Hygiène personnelle': ['Papier hygiénique', 'Savon', 'Dentifrice', 'Shampoing', 'Serviettes hygiéniques', 'Couches', 'Produits de beauté'],
  'Entretien de la maison': ['Produits ménagers', 'Lessive', 'Gaz / charbon', 'Réparations', 'Ustensiles'],
  'Eau et électricité (Jirama)': ['Électricité', 'Eau', 'Bougies / piles'],
  'Loyer': ['Loyer', 'Charges'],
  'Transport': ['Taxi-be', 'Taxi', 'Pousse-pousse', 'Carburant privé'],
  'Santé': ['Médicaments', 'Consultation', 'Analyses', 'Dentiste'],
  'Scolarité': ['Écolage', 'Fournitures', 'Uniformes', 'Cantine', 'Cours particuliers'],
  'Communication': ['Crédit téléphone', 'Internet', 'Abonnement TV'],
  'Habillement': ['Vêtements', 'Chaussures', 'Couture'],
  'Loisirs': ['Sorties', 'Sport', 'Jeux', 'Cinéma / concert'],
  'Dons et cérémonies': ['Église / offrande', 'Mariage', 'Funérailles', 'Anniversaire', 'Aide à un proche'],
  'Frais de voiture': ['Carburant', 'Entretien', 'Réparation', 'Assurance', 'Taxes et papiers', 'Parking / lavage'],
  'Imprévus': ['Urgence', 'Amende', 'Perte / vol'],
  'Autres': ['Divers'],
};

class Store extends ChangeNotifier {
  late Database db;
  final Map<String, Rec> all = {};
  String? meId;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  // ---------------------------------------------------------------- init
  Future<void> init() async {
    final dir = await getDatabasesPath();
    db = await openDatabase(
      p.join(dir, 'famille_budget.db'),
      version: 1,
      onCreate: (d, v) => d.execute(
          'CREATE TABLE rec(id TEXT PRIMARY KEY, kind TEXT, data TEXT, u INTEGER, d INTEGER)'),
    );
    for (final r in await db.query('rec')) {
      final id = r['id'] as String;
      all[id] = Rec(id, r['kind'] as String,
          Map<String, dynamic>.from(jsonDecode(r['data'] as String) as Map),
          r['u'] as int, (r['d'] as int) == 1);
    }
    if (!all.containsKey('meta')) await _seed();
    if (!all.containsKey('local')) {
      await _write(db, Rec('local', 'local', {'theme': 'auto', 'lang': 'fr'}, 0, false));
      all['local'] = Rec('local', 'local', {'theme': 'auto', 'lang': 'fr'}, 0, false);
    }
    await runRecurring();
  }

  Map<String, Object?> _row(Rec r) => {
        'id': r.id, 'kind': r.kind, 'data': jsonEncode(r.data),
        'u': r.u, 'd': r.d ? 1 : 0,
      };

  /// Met à jour sans changer l'ordre (pas de INSERT OR REPLACE).
  Future<void> _write(DatabaseExecutor ex, Rec r) async {
    final n = await ex.update('rec', _row(r), where: 'id = ?', whereArgs: [r.id]);
    if (n == 0) await ex.insert('rec', _row(r));
  }

  Future<void> _seed() async {
    final recs = <Rec>[];
    void add(String id, String kind, J data) =>
        recs.add(Rec(id, kind, data, 0, false)); // u=0 : toute modification l'emporte
    add('meta', 'meta', {'household': 'Famille Raoliarison'});
    add('mem_0', 'member', {'name': 'Papa', 'role': 'parent', 'color': kMemberColors[0], 'pin': ''});
    add('mem_1', 'member', {'name': 'Maman', 'role': 'parent', 'color': kMemberColors[1], 'pin': ''});
    const srcs = ['Papa', 'Maman', 'Voiture 1', 'Voiture 2', 'Argent de poche', 'Aide familiale', 'Loyer perçu', 'Autre revenu'];
    for (var i = 0; i < srcs.length; i++) {
      add('src_$i', 'source', {'name': srcs[i], 'car': i == 2 || i == 3, 'active': true});
    }
    const accs = ['Espèces', 'MVola', 'Orange Money', 'Airtel Money', 'Banque'];
    for (var i = 0; i < accs.length; i++) {
      add('acc_$i', 'account', {'name': accs[i], 'opening': 0});
    }
    var i = 0;
    _seedCats.forEach((name, subs) {
      add('cat_$i', 'category', {
        'name': name,
        'subs': [
          for (var j = 0; j < subs.length; j++) {'id': 'sub_${i}_$j', 'name': subs[j], 'active': true}
        ],
      });
      i++;
    });
    await db.transaction((txn) async {
      for (final r in recs) {
        await _write(txn, r);
      }
    });
    for (final r in recs) {
      all[r.id] = r;
    }
  }

  // ---------------------------------------------------------------- CRUD
  Future<Rec> put(String kind, J data, {String? id}) async {
    final r = Rec(id ?? _uuid.v4(), kind, data, _now, false);
    all[r.id] = r;
    await _write(db, r);
    notifyListeners();
    return r;
  }

  Future<void> remove(String id) async {
    final r = all[id];
    if (r == null) return;
    r.d = true;
    r.u = _now;
    await _write(db, r);
    notifyListeners();
  }

  List<Rec> list(String kind) =>
      all.values.where((r) => r.kind == kind && !r.d).toList();

  // ---------------------------------------------------------------- session / réglages
  Rec? get me {
    final r = all[meId];
    return (r != null && !r.d) ? r : null;
  }

  bool get isParent => me?.str('role') == 'parent';
  void login(String id) {
    meId = id;
    notifyListeners();
  }

  void logout() {
    meId = null;
    notifyListeners();
  }

  String get household => (all['meta']?.data['household'] ?? 'Famille') as String;
  Future<void> setHousehold(String n) async {
    final m = all['meta']!;
    await put('meta', {...m.data, 'household': n}, id: 'meta');
  }

  ThemeMode get themeMode {
    switch (all['local']!.data['theme']) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String get lang => (all['local']!.data['lang'] ?? 'fr') as String;
  String get themeKey => (all['local']!.data['theme'] ?? 'auto') as String;

  Future<void> setLocal(String k, String v) async {
    final l = all['local']!;
    l.data[k] = v;
    await _write(db, l);
    notifyListeners();
  }

  // ---------------------------------------------------------------- requêtes
  List<Rec> txns() {
    final l = list('txn');
    if (isParent) return l;
    return l.where((t) => t.str('memberId') == meId).toList();
  }

  List<Rec> between(DateTime from, DateTime to, {String? member}) =>
      txns().where((t) {
        final d = t.date;
        return !d.isBefore(from) &&
            d.isBefore(to) &&
            (member == null || t.str('memberId') == member);
      }).toList();

  double sumOf(Iterable<Rec> l, String type) => l
      .where((t) => t.str('type') == type)
      .fold(0.0, (s, t) => s + t.dbl('amount'));

  double balance(String accId) {
    var b = all[accId]?.dbl('opening') ?? 0;
    for (final t in list('txn')) {
      final a = t.dbl('amount');
      switch (t.str('type')) {
        case 'income':
          if (t.str('accountId') == accId) b += a;
          break;
        case 'expense':
          if (t.str('accountId') == accId) b -= a;
          break;
        case 'transfer':
          if (t.str('accountId') == accId) b -= a;
          if (t.str('toAccountId') == accId) b += a;
          break;
      }
    }
    return b;
  }

  double get totalBalance =>
      list('account').fold(0.0, (s, a) => s + balance(a.id));

  // ---------------------------------------------------------------- noms
  String nameOf(String? id) => id == null ? '—' : (all[id]?.name ?? '—');

  List<Map> subsOf(String? catId, {bool activeOnly = false}) {
    final c = all[catId];
    if (c == null) return [];
    return [
      for (final s in (c.data['subs'] as List))
        if (!activeOnly || (s as Map)['active'] != false) Map.from(s as Map)
    ];
  }

  String subName(String? catId, String? subId) {
    if (subId == null) return '';
    for (final s in subsOf(catId)) {
      if (s['id'] == subId) return s['name'] as String;
    }
    return '';
  }

  Future<String> addCategory(String name) async =>
      (await put('category', {'name': name, 'subs': []})).id;

  Future<String> addSub(String catId, String name) async {
    final c = all[catId]!;
    final subs = List<dynamic>.from(c.data['subs'] as List);
    final id = _uuid.v4();
    subs.add({'id': id, 'name': name, 'active': true});
    await put('category', {...c.data, 'subs': subs}, id: catId);
    return id;
  }

  Future<String> addSource(String name, {bool car = false}) async =>
      (await put('source', {'name': name, 'car': car, 'active': true})).id;

  // ---------------------------------------------------------------- récurrents
  Future<void> runRecurring() async {
    final now = DateTime.now();
    final nowIdx = now.year * 12 + now.month - 1;
    for (final r in list('recurring')) {
      final start = r.data['start'] as int;
      final day = r.data['day'] as int;
      for (var i = start; i <= nowIdx; i++) {
        final dt = DateTime(i ~/ 12, i % 12 + 1, day);
        if (dt.isAfter(now)) break;
        final id = 'rt_${r.id}_$i'; // id déterministe : pas de doublon entre téléphones
        if (all.containsKey(id)) continue;
        await put('txn', {
          ...Map<String, dynamic>.from(r.data['tmpl'] as Map),
          'date': dt.millisecondsSinceEpoch,
          'rec': r.id,
        }, id: id);
      }
    }
  }

  Future<void> addRecurring(J tmpl, int day) async {
    final now = DateTime.now();
    await put('recurring', {
      'tmpl': tmpl,
      'day': math.min(day, 28),
      'start': now.year * 12 + now.month, // dès le mois prochain
    });
  }

  // ---------------------------------------------------------------- partage / sauvegarde
  Future<File> exportFile() async {
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path,
        'famille_budget_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json'));
    await f.writeAsString(jsonEncode({
      'app': 'famille_budget',
      'v': 1,
      'records': [
        for (final r in all.values)
          if (r.kind != 'local')
            {'id': r.id, 'kind': r.kind, 'data': r.data, 'u': r.u, 'd': r.d ? 1 : 0}
      ],
    }));
    return f;
  }

  /// Fusion : la modification la plus récente l'emporte, aucun doublon (ids uniques).
  Future<int> importFile(String path) async {
    final j = jsonDecode(await File(path).readAsString());
    if (j is! Map || j['app'] != 'famille_budget') {
      throw const FormatException('Fichier invalide');
    }
    var n = 0;
    await db.transaction((txn) async {
      for (final e in (j['records'] as List)) {
        final id = e['id'] as String;
        final kind = e['kind'] as String;
        final u = e['u'] as int;
        if (kind == 'local') continue;
        final cur = all[id];
        if (cur == null || u > cur.u) {
          final r = Rec(id, kind, Map<String, dynamic>.from(e['data'] as Map), u, e['d'] == 1);
          await _write(txn, r);
          all[id] = r;
          n++;
        }
      }
    });
    notifyListeners();
    return n;
  }

  Future<File> csvFile(List<Rec> ts) async {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final df = DateFormat('dd/MM/yyyy');
    final sb = StringBuffer('\uFEFF');
    sb.writeln('Date;Type;Montant;Catégorie;Sous-catégorie;Source;Compte;Membre;Voiture;Note');
    final l = [...ts]..sort((a, b) => a.date.compareTo(b.date));
    for (final t in l) {
      final ty = t.str('type');
      sb.writeln([
        df.format(t.date),
        ty == 'income' ? 'Revenu' : ty == 'expense' ? 'Dépense' : 'Transfert',
        t.dbl('amount').toStringAsFixed(0),
        q(ty == 'expense' ? nameOf(t.str('catId')) : ''),
        q(ty == 'expense' ? subName(t.str('catId'), t.str('subId')) : ''),
        q(ty == 'income' ? nameOf(t.str('sourceId')) : ''),
        q(ty == 'transfer'
            ? '${nameOf(t.str('accountId'))} → ${nameOf(t.str('toAccountId'))}'
            : nameOf(t.str('accountId'))),
        q(nameOf(t.str('memberId'))),
        q(t.str('carId') == null ? '' : nameOf(t.str('carId'))),
        q(t.str('note') ?? ''),
      ].join(';'));
    }
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path,
        'famille_budget_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv'));
    await f.writeAsString(sb.toString());
    return f;
  }
}
