import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'store.dart';

/// Petit serveur de synchronisation intégré directement dans l'application :
/// l'appareil qui « héberge » le foyer ouvre ce serveur (sur le réseau
/// Wi-Fi local), et les autres appareils s'y connectent par WebSocket —
/// aucun programme à installer séparément.
///
/// Protocole volontairement minimal, en JSON, un message par ligne :
///  - client → serveur, au moment de se connecter :
///      {type:'auth', household, secret, name}
///  - serveur → client : {type:'auth_ok'} ou {type:'auth_fail'}
///  - serveur → client, pour chaque enregistrement existant puis à chaque
///    changement : {type:'record', rid, kind, data, u, d}
///  - serveur → client, une fois l'envoi initial terminé : {type:'synced'}
///  - client → serveur, à chaque changement local : {type:'record', ...}
///
/// Le serveur ne fait que relayer : il applique chaque enregistrement reçu
/// dans son PROPRE Store local (comme n'importe quel autre appareil, via la
/// règle « la modification la plus récente l'emporte »), puis le retransmet
/// aux autres appareils connectés. L'appareil hôte est donc un participant
/// comme les autres, pas un simple tuyau.
class EmbeddedServer extends ChangeNotifier {
  EmbeddedServer._();
  static final EmbeddedServer instance = EmbeddedServer._();

  static const defaultPort = 8095;

  HttpServer? _http;
  final List<_Client> _clients = [];
  String? household, secret;
  int port = defaultPort;
  String? lastError;

  bool get running => _http != null;

  Future<bool> start({required String household, required String secret, int? preferredPort}) async {
    await stop();
    this.household = household;
    this.secret = secret;
    lastError = null;
    for (final p in [preferredPort ?? defaultPort, defaultPort + 1, defaultPort + 2]) {
      try {
        _http = await HttpServer.bind(InternetAddress.anyIPv4, p);
        port = p;
        break;
      } catch (_) {
        continue;
      }
    }
    if (_http == null) {
      lastError = 'Impossible d’ouvrir un port réseau (8095-8097 déjà utilisés ?)';
      notifyListeners();
      return false;
    }
    _http!.listen(_handleRequest, onError: (_) {});
    notifyListeners();
    return true;
  }

  Future<void> stop() async {
    for (final c in [..._clients]) {
      await c.sock.close();
    }
    _clients.clear();
    await _http?.close(force: true);
    _http = null;
    notifyListeners();
  }

  /// Les adresses IPv4 locales de cet appareil sur le Wi-Fi, pour les
  /// afficher/inclure dans le QR code d'appairage.
  static Future<List<String>> localIPs() async {
    final out = <String>[];
    try {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false)) {
        for (final a in i.addresses) {
          if (!a.isLoopback) out.add(a.address);
        }
      }
    } catch (_) {}
    return out;
  }

  Future<void> _handleRequest(HttpRequest req) async {
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response
        ..statusCode = HttpStatus.ok
        ..write('Famille Budget — serveur de synchronisation')
        ..close();
      return;
    }
    try {
      final ws = await WebSocketTransformer.upgrade(req);
      final client = _Client(ws);
      _clients.add(client);
      ws.listen(
        (raw) => _onMessage(client, raw),
        onDone: () => _clients.remove(client),
        onError: (_) => _clients.remove(client),
        cancelOnError: true,
      );
    } catch (_) {}
  }

  Future<void> _onMessage(_Client c, dynamic raw) async {
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
    } catch (_) {
      return;
    }
    switch (m['type']) {
      case 'auth':
        if (m['household'] == household && m['secret'] == secret) {
          c.authed = true;
          c.name = (m['name'] as String?) ?? 'Appareil';
          _send(c, {'type': 'auth_ok'});
          for (final r in store.all.values) {
            if (r.kind == 'local') continue;
            _send(c, {'type': 'record', 'rid': r.id, 'kind': r.kind, 'data': r.data, 'u': r.u, 'd': r.d});
          }
          _send(c, {'type': 'synced'});
          notifyListeners();
        } else {
          _send(c, {'type': 'auth_fail'});
          await c.sock.close();
        }
        break;
      case 'record':
        if (!c.authed) return;
        final kind = m['kind'] as String?;
        final rid = m['rid'] as String?;
        if (kind == null || rid == null || kind == 'local') return;
        await store.mergeRemote(
          rid, kind,
          Map<String, dynamic>.from(m['data'] as Map? ?? {}),
          ((m['u'] as num?) ?? 0).toInt(),
          m['d'] == true,
        );
        // On relaie tel quel aux autres appareils connectés, même si la
        // fusion locale n'a rien changé : eux peuvent ne pas encore l'avoir.
        for (final other in _clients) {
          if (other != c && other.authed) _send(other, m);
        }
        break;
    }
  }

  void _send(_Client c, Map<String, dynamic> m) {
    try {
      c.sock.add(jsonEncode(m));
    } catch (_) {}
  }

  /// Diffuse un enregistrement à tous les appareils connectés (appelé par
  /// Sync quand CET appareil, en tant qu'hôte, a lui-même un changement
  /// local à propager).
  void broadcast(Map<String, dynamic> m) {
    for (final c in _clients) {
      if (c.authed) _send(c, m);
    }
  }

  int get connectedCount => _clients.where((c) => c.authed).length;
}

class _Client {
  final WebSocket sock;
  bool authed = false;
  String name = '';
  _Client(this.sock);
}
