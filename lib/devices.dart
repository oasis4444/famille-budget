import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'embedded_server.dart';
import 'store.dart';
import 'sync.dart';
import 'ui.dart';

/// Encode/décode le petit paquet transmis par QR code (ou collé à la main) :
/// l'adresse de l'appareil hôte sur le Wi-Fi + les identifiants du foyer.
/// Ce paquet est volontairement minuscule — il ne transporte pas
/// l'historique des opérations, seulement cette « clé » de connexion.
String _encodePacket(String url, String household, String secret, String name) =>
    jsonEncode({'fb': 1, 'url': url, 'h': household, 's': secret, 'n': name});

Map<String, dynamic>? _decodePacket(String raw) {
  try {
    final j = jsonDecode(raw.trim());
    if (j is Map && j['fb'] == 1 && j['url'] != null && j['h'] != null && j['s'] != null) {
      return Map<String, dynamic>.from(j);
    }
  } catch (_) {}
  return null;
}

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Sync.instance, EmbeddedServer.instance]),
      builder: (_, __) {
        final s = Sync.instance;
        return Scaffold(
          appBar: AppBar(title: const Text('Appareils et synchronisation')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (!s.configured) ...[
              const Panel(
                child: Text(
                  'Reliez vos appareils pour que les opérations se mettent à jour automatiquement '
                  'entre eux — aucune installation séparée n’est nécessaire. Un appareil « héberge », '
                  'les autres le rejoignent. Cela fonctionne tant que les appareils sont sur le même Wi-Fi.',
                ),
              ),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Héberger notre foyer (cet appareil)'),
                  onPressed: () => _becomeHost(context),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Rejoindre un foyer (scanner le code)'),
                  onPressed: () => _scanJoin(context),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Rejoindre un foyer (coller le code)'),
                  onPressed: () => _pasteJoin(context),
                ),
              ),
            ] else ...[
              _StatusPanel(s: s),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Ajouter un autre appareil'),
                  onPressed: () => _showQr(context, s.url!, s.household!, s.secret!, store.household),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.link_off, color: kLaterite),
                  label: const Text('Arrêter la synchronisation', style: TextStyle(color: kLaterite)),
                  onPressed: () async {
                    if (await confirm(context, 'Cet appareil arrêtera de se synchroniser. Les données déjà reçues restent sur l’appareil.')) {
                      await s.forget();
                    }
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Panel(
              child: Text(
                'La synchronisation est un complément : le partage par fichier WhatsApp (Réglages > '
                'Sauvegarde et partage) continue de fonctionner, y compris sans Wi-Fi.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _becomeHost(BuildContext context) async {
    final r = await Sync.instance.becomeHost(deviceLabel: store.me?.name);
    if (!context.mounted) return;
    if (r == null) {
      snack(context, Sync.instance.lastError ?? 'Impossible de démarrer');
      return;
    }
    snack(context, 'Cet appareil héberge maintenant le foyer ✓');
    _showQr(context, r['url']!, r['household']!, r['secret']!, store.household);
  }

  void _showQr(BuildContext context, String url, String hh, String secret, String name) {
    final packet = _encodePacket(url, hh, secret, name);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Scannez ce code avec le nouvel appareil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Les deux appareils doivent être sur le même Wi-Fi', style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(data: packet, size: 220),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copier le code (sur PC, si pas de caméra)'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: packet));
              snack(ctx, 'Code copié ✓');
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _scanJoin(BuildContext context) async {
    final raw = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _ScanScreen()));
    if (raw == null) return;
    if (context.mounted) await _join(context, raw);
  }

  Future<void> _pasteJoin(BuildContext context) async {
    final raw = await askText(context, 'Collez le code reçu de l’autre appareil');
    if (raw == null || raw.isEmpty) return;
    if (context.mounted) await _join(context, raw);
  }

  Future<void> _join(BuildContext context, String raw) async {
    final p = _decodePacket(raw);
    if (p == null) {
      if (context.mounted) snack(context, 'Code non reconnu');
      return;
    }
    await Sync.instance.joinHousehold(
      url: p['url'] as String,
      household: p['h'] as String,
      secret: p['s'] as String,
      device: store.me?.name,
    );
    if (context.mounted) {
      snack(context, Sync.instance.connected ? 'Appareil relié ✓' : 'Appareil enregistré — connexion en cours…');
    }
  }
}

class _StatusPanel extends StatelessWidget {
  final Sync s;
  const _StatusPanel({required this.s});
  @override
  Widget build(BuildContext context) {
    final host = s.isHost;
    final ok = host || s.connected;
    final n = EmbeddedServer.instance.connectedCount;
    return Panel(
      color: ok ? kIncome.withOpacity(.12) : kLaterite.withOpacity(.12),
      child: Row(children: [
        Icon(host ? Icons.wifi_tethering : (s.connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
            color: ok ? kIncome : kLaterite),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              host
                  ? (n == 0 ? 'Cet appareil héberge le foyer' : 'Cet appareil héberge le foyer — $n appareil(s) connecté(s)')
                  : s.connected
                      ? 'Connecté — les données se mettent à jour automatiquement'
                      : s.connecting
                          ? 'Connexion en cours…'
                          : 'Hors ligne — les opérations sont enregistrées et seront envoyées au retour du Wi-Fi',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (!host) Text('Hôte : ${s.url}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          ]),
        ),
        if (!host && !s.connected && !s.connecting)
          IconButton(icon: const Icon(Icons.refresh), onPressed: s.connect),
      ]),
    );
  }
}

class _ScanScreen extends StatelessWidget {
  const _ScanScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scanner le code')),
        body: MobileScanner(
          onDetect: (capture) {
            for (final b in capture.barcodes) {
              final v = b.rawValue;
              if (v != null) {
                Navigator.pop(context, v);
                return;
              }
            }
          },
        ),
      );
}
