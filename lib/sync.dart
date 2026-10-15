import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'embedded_server.dart';
import 'store.dart';

/// Connexion de CET appareil au foyer : soit il est lui-même l'hôte (voir
/// EmbeddedServer, ses propres écritures locales sont alors diffusées
/// directement par le serveur intégré), soit il se connecte en client au
/// serveur d'un autre appareil du foyer via WebSocket. Même protocole dans
/// les deux cas (voir embedded_server.dart).
///
/// Hors ligne : les écritures locales continuent normalement (Store ne
/// dépend jamais du réseau). Elles sont mises en file d'attente et envoyées
/// dès que l'appareil hôte redevient joignable.
class Sync extends ChangeNotifier {
  Sync._();
  static final Sync instance = Sync._();

  WebSocket? _ws;
  Timer? _retryTimer;
  Completer<bool>? _authWait;

  String? url, household, secret, deviceName;
  bool connecting = false;
  bool connected = false;
  String? lastError;
  final List<Rec> _outbox = [];

  bool get configured => url != null && household != null && secret != null;

  /// Charge la config enregistrée sur CET appareil (jamais synchronisée,
  /// stockée dans le Rec local 'local', comme le thème ou la langue) puis
  /// tente de se connecter si elle existe. Si cet appareil était l'hôte lors
  /// de la dernière utilisation, relance aussi le serveur intégré.
  Future<void> init() async {
    final l = store.all['local']?.data ?? {};
    url = l['syncUrl'] as String?;
    household = l['syncHousehold'] as String?;
    secret = l['syncSecret'] as String?;
    deviceName = l['syncDevice'] as String?;
    store.onLocalWrite = _onLocalWrite;
    try {
      // Non supporté sur certaines configurations (ex. Linux sans
      // NetworkManager) : la reconnexion automatique par minuterie
      // (_scheduleRetry) prend le relais dans ce cas.
      Connectivity().onConnectivityChanged.listen((_) {
        if (configured && !connected) connect();
      });
    } catch (_) {}
    if (l['syncIsHost'] == true && household != null && secret != null) {
      await EmbeddedServer.instance.start(household: household!, secret: secret!);
    }
    if (configured) unawaited(connect());
  }

  /// Démarre le serveur intégré sur CET appareil (il devient l'hôte du
  /// foyer) et renvoie les informations à transmettre aux autres appareils
  /// par QR code. Génère un nouveau foyer si aucun n'existe déjà.
  Future<Map<String, String>?> becomeHost({String? deviceLabel}) async {
    final hh = household ?? newHouseholdId();
    final sec = secret ?? newSecret();
    final ok = await EmbeddedServer.instance.start(household: hh, secret: sec);
    if (!ok) {
      lastError = EmbeddedServer.instance.lastError;
      notifyListeners();
      return null;
    }
    final ips = await EmbeddedServer.localIPs();
    final ip = ips.isNotEmpty ? ips.first : '127.0.0.1';
    final myUrl = 'ws://$ip:${EmbeddedServer.instance.port}/ws';
    final l = store.all['local']!;
    await store.put('local', {
      ...l.data,
      'syncUrl': myUrl,
      'syncHousehold': hh,
      'syncSecret': sec,
      'syncDevice': deviceLabel ?? l.data['syncDevice'] ?? 'Appareil',
      'syncIsHost': true,
    }, id: 'local');
    url = myUrl;
    household = hh;
    secret = sec;
    connected = true; // on est son propre hôte : toujours « connecté »
    notifyListeners();
    return {'url': myUrl, 'household': hh, 'secret': sec};
  }

  /// Rejoint le foyer d'un autre appareil (adresse reçue par QR code ou
  /// collée à la main) : CET appareil devient un simple client.
  Future<void> joinHousehold({required String url, required String household, required String secret, String? device}) async {
    await EmbeddedServer.instance.stop();
    final l = store.all['local']!;
    await store.put('local', {
      ...l.data,
      'syncUrl': url,
      'syncHousehold': household,
      'syncSecret': secret,
      'syncDevice': device ?? l.data['syncDevice'] ?? 'Appareil',
      'syncIsHost': false,
    }, id: 'local');
    this.url = url;
    this.household = household;
    this.secret = secret;
    deviceName = device ?? deviceName;
    await connect();
  }

  bool get isHost => (store.all['local']?.data['syncIsHost'] as bool?) ?? false;

  Future<void> forget() async {
    await EmbeddedServer.instance.stop();
    await disconnect();
    final l = store.all['local']!;
    final d = {...l.data}..removeWhere((k, _) => k.toString().startsWith('sync'));
    await store.put('local', d, id: 'local');
    url = household = secret = deviceName = null;
    notifyListeners();
  }

  Future<void> disconnect() async {
    _retryTimer?.cancel();
    await _ws?.close();
    _ws = null;
    connected = false;
    notifyListeners();
  }

  static String newHouseholdId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  static String newSecret() {
    final r = DateTime.now().microsecondsSinceEpoch ^ identityHashCode(Object());
    return r.toRadixString(36) + (r * 2654435761 % 1000003).toRadixString(36);
  }

  Future<bool> connect() async {
    if (!configured || isHost) return isHost; // l'hôte n'a personne à rejoindre
    connecting = true;
    lastError = null;
    notifyListeners();
    try {
      final ws = await WebSocket.connect(url!).timeout(const Duration(seconds: 8));
      _ws = ws;
      _authWait = Completer<bool>();
      ws.listen(_onMessage, onDone: _onClosed, onError: (_) => _onClosed(), cancelOnError: true);
      _send({'type': 'auth', 'household': household, 'secret': secret, 'name': deviceName ?? 'Appareil'});
      final ok = await _authWait!.future.timeout(const Duration(seconds: 8), onTimeout: () => false);
      connecting = false;
      if (!ok) {
        lastError = 'Identifiants refusés par l’hôte';
        connected = false;
        notifyListeners();
        await _ws?.close();
        _ws = null;
        return false;
      }
      connected = true;
      notifyListeners();
      unawaited(_flushOutbox());
      return true;
    } catch (e) {
      connecting = false;
      connected = false;
      lastError = '$e';
      notifyListeners();
      _scheduleRetry();
      return false;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 15), () {
      if (configured && !connected && !isHost) connect();
    });
  }

  void _onClosed() {
    _ws = null;
    if (connected) {
      connected = false;
      notifyListeners();
    }
    _scheduleRetry();
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
    } catch (_) {
      return;
    }
    switch (m['type']) {
      case 'auth_ok':
        if (!(_authWait?.isCompleted ?? true)) _authWait!.complete(true);
        break;
      case 'auth_fail':
        if (!(_authWait?.isCompleted ?? true)) _authWait!.complete(false);
        break;
      case 'record':
        final kind = m['kind'] as String?;
        final rid = m['rid'] as String?;
        if (kind == null || rid == null) return;
        store.mergeRemote(
          rid, kind,
          Map<String, dynamic>.from(m['data'] as Map? ?? {}),
          ((m['u'] as num?) ?? 0).toInt(),
          m['d'] == true,
        );
        break;
    }
  }

  void _send(Map<String, dynamic> m) {
    try {
      _ws?.add(jsonEncode(m));
    } catch (_) {}
  }

  void _onLocalWrite(Rec r) {
    final msg = {'type': 'record', 'rid': r.id, 'kind': r.kind, 'data': r.data, 'u': r.u, 'd': r.d};
    if (EmbeddedServer.instance.running) {
      // Cet appareil EST l'hôte : on diffuse directement aux autres,
      // pas besoin de passer par une connexion sortante.
      EmbeddedServer.instance.broadcast(msg);
    } else if (connected) {
      _send(msg);
    } else if (configured) {
      _outbox.add(r);
    }
  }

  Future<void> _flushOutbox() async {
    final items = [..._outbox];
    _outbox.clear();
    for (final r in items) {
      _send({'type': 'record', 'rid': r.id, 'kind': r.kind, 'data': r.data, 'u': r.u, 'd': r.d});
    }
  }
}
