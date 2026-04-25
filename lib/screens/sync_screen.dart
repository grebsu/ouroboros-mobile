import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/backup_model.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../services/mdns_advertiser.dart';
import '../services/mdns_discovery_service.dart';
import '../services/sync_service.dart';
import 'package:ouroboros_mobile/main.dart' as main_app;
import 'package:ouroboros_mobile/screens/splash_screen.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({Key? key}) : super(key: key);

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  static const int _syncPort = 5000; // Constante para a porta de sincronização

  final MDNSDiscoveryService _discover = MDNSDiscoveryService();
  final SyncService _sync =
      SyncService(); // Keep this as it's a singleton and we'll access it directly
  final Uuid _uuid = Uuid();
  final TextEditingController _ipController = TextEditingController();

  final Map<String, Map<String, dynamic>> _found = {}; // key ip:port
  Map<String, dynamic> _paired = {};

  StreamSubscription? _incomingSub;
  StreamSubscription? _foundSub;

  String _myId = '';

  @override
  void initState() {
    super.initState();
    _myId = _uuid.v4();
    _loadPaired();

    _discover.setOnDeviceFound((name, ip, port) {
      final key = '$ip:$port';
      // Evitar adicionar o próprio dispositivo à lista de encontrados se o userId for o mesmo
      final currentUserId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser?.name;
      if (currentUserId != null &&
          name.startsWith('Ouroboros-$currentUserId')) {
        return; // Não adicionar o próprio dispositivo
      }

      setState(() {
        _found[key] = {'name': name, 'ip': ip, 'port': port};
      });
    });

    _incomingSub = _sync.incomingRequests.listen((req) {
      if (mounted) {
        _showIncomingPairDialog(req);
      }
    });

    // Iniciar apenas a descoberta mDNS, já que o servidor e anunciante são globais.
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.name;
    if (currentUserId != null) {
      // Usar uma instanceName mais robusta para init do discover
      _discover.init('_ouro._tcp.local', _syncPort, 'Ouroboros-$currentUserId');
      _discover.startDiscovery();
    } else {
      // Se não há userId, a descoberta não pode ser iniciada, mas o servidor global pode estar rodando.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erro: Usuário não está logado para iniciar a descoberta.',
            ),
          ),
        );
      });
    }
  }

  Future<void> _loadPaired() async {
    final map = await _sync.getPairedDevices();
    if (mounted) {
      setState(() {
        _paired = map;
      });
    }
  }

  Future<void> _pairWith(String ip, int port, String name) async {
    final res = await _sync.sendPairRequest(
      ip,
      port,
      'Ouroboros-${Platform.localHostname}',
      _myId,
    );

    if (!mounted) return;

    if (res['status'] == 'accepted' && res['token'] != null) {
      final token = (res['token'] as String?) ?? "";
      final syncKey = (res['syncKey'] as String?); // Retrieve syncKey from response
      await _sync.storePairedDevice(ip, port, token, name, syncKey); // Store syncKey
      await _loadPaired();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pareado com $name ($ip:$port)')));
    } else if (res['status'] == 'rejected') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pareamento rejeitado por $name')));
    } else if (res['status'] == 'timeout') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sem resposta do dispositivo')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro pareando: ${res.toString()}')),
      );
    }
  }

  Future<void> _showIncomingPairDialog(PairRequest req) async {
    if (!mounted) return;
    final decision = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Solicitação de pareamento'),
          content: Text(
            'Deseja parear com "${req.deviceName}" (${req.remote}:${req.remotePort})?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Recusar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Aceitar'),
            ),
          ],
        );
      },
    );

    if (decision == true) {
      final token = _uuid.v4();
      final response = await _sync.respondToPairRequest(req.id,
          accepted: true, token: token, clientSyncKey: req.syncKey); // Pass clientSyncKey
      final serverSyncKey = (response['syncKey'] as String?); // Retrieve server's syncKey

      await _sync.storePairedDevice(
        req.remote.address,
        _syncPort,
        token,
        req.deviceName,
        serverSyncKey, // Store server's syncKey
      );
      await _loadPaired();
    } else {
      await _sync.respondToPairRequest(req.id, accepted: false);
    }
  }

  Future<void> _removePaired(String key) async {
    final parts = key.split(':');
    final ip = parts[0];
    final port = int.tryParse(parts[1]) ?? _syncPort;
    await _sync.removePairedDevice(ip, port);
    await _loadPaired();
  }

  Future<void> _clearAll() async {
    await _sync.clearAllPairedDevices();
    await _loadPaired();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todos os dispositivos pareados foram removidos.'),
      ),
    );
  }

  Future<void> _connectManually() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira um endereço IP.')),
      );
      return;
    }

    const int defaultPort = _syncPort;
    await _pairWith(ip, defaultPort, ip);
  }

  Future<void> _showSyncSuccessAndRestart() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sincronização Concluída!'),
        content: const Text('Os dados foram recebidos.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              main_app.restartNotifier.value++;
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncNow() async {
    if (_paired.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum par disponível para sincronizar.'),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.name;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Usuário não está logado.')),
      );
      return;
    }

    final first = _paired.entries.first;
    final info = first.value as Map<String, dynamic>;
    final ip = info['ip'];
    final port = info['port'];
    final token = info['token'];
    final syncKey = info['syncKey'] as String?; // Retrieve syncKey for the paired device

    if (ip == null || port == null || token == null || syncKey == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados do par estão incompletos ou chave de sincronização ausente.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Sincronizando com ${info['name']}...')),
    );

    final uri = Uri.parse('http://$ip:$port/sync');
    try {
      // 1. Exportar os dados de backup do cliente
      final clientBackupData = await DatabaseService.instance.exportBackupData(
        userId,
      );
      final clientJsonData = json.encode(clientBackupData.toMap());
      final encryptedClientJsonData = _sync.encryptData(clientJsonData, syncKey); // Encrypt client data

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'X-User-ID': userId,
            },
            body:
                encryptedClientJsonData, // Enviar os dados do cliente criptografados
          )
          .timeout(const Duration(seconds: 60));

      switch (response.statusCode) {
        case 200:
          // 2. Receber e importar os dados mesclados de volta ao cliente
          final decryptedResponseBody = _sync.decryptData(utf8.decode(response.bodyBytes), syncKey); // Decrypt response
          final mergedBackupData = BackupData.fromMap(
            json.decode(decryptedResponseBody) as Map<String, dynamic>,
          );
          await DatabaseService.instance.importMergedData(
            mergedBackupData,
            userId,
          ); // Usar o novo método
          await _showSyncSuccessAndRestart();
          break;
        case 403:
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Falha na sincronização: Token inválido. Por favor, limpe os pareamentos e tente novamente.',
              ),
            ),
          );
          break;
        case 409:
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Falha na sincronização: Contas de usuário diferentes nos dispositivos.',
              ),
            ),
          );
          break;
        default:
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Falha na sincronização: ${response.statusCode} - ${response.body}',
              ),
            ),
          );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erro de rede ao sincronizar: $e')),
      );
    }
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _foundSub?.cancel();
    _discover.stopDiscovery(); // Stop discovery when leaving the screen
    _ipController.dispose();
    super.dispose();
  }

  Widget _buildFoundList() {
    if (_found.isEmpty) {
      return const Text('Nenhum dispositivo encontrado.');
    }
    return Column(
      children: _found.entries.map((e) {
        final key = e.key;
        final value = e.value;
        final String ip = value['ip'] as String;
        final int port = value['port'] as int;
        final String name = value['name'] as String;
        return ListTile(
          title: Text('$name'),
          subtitle: Text('$ip:$port'),
          trailing: ElevatedButton(
            child: const Text('Parear'),
            onPressed: () => _pairWith(ip, port, name),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPairedList() {
    if (_paired.isEmpty) {
      return const Text('Nenhum dispositivo pareado.');
    }
    return Column(
      children: _paired.entries.map((e) {
        final key = e.key;
        final info = e.value as Map<String, dynamic>;
        final name = (info['name'] as String?) ?? key;
        final ip = (info['ip'] as String?) ?? key.split(':').first;
        final port = info['port'] ?? _syncPort;
        return ListTile(
          title: Text(name),
          subtitle: Text('$ip:$port'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _removePaired(key),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronização Wi-Fi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String?>(
              future: _getLocalAddress(),
              builder: (ctx, snap) {
                return Text('Meu IP: ${snap.data ?? "Detectando..."}');
              },
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Conectar via IP',
                      hintText: 'Ex: 192.168.1.100',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: _connectManually,
                  tooltip: 'Conectar manualmente via IP',
                ),
              ],
            ),
            const Divider(),
            Text(
              'Dispositivos Encontrados:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _buildFoundList(),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dispositivos Pareados:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: _clearAll,
                  child: const Text('Limpar Todos'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
            _buildPairedList(),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _syncNow,
              child: const Text('Sincronizar Agora (com primeiro par)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getLocalAddress() async {
    try {
      for (var iface in await NetworkInterface.list()) {
        for (var addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
