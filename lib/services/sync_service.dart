// lib/services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ouroboros_mobile/models/backup_model.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class PairRequest {
  final String id;
  final String deviceName;
  final String deviceId;
  final InternetAddress remote;
  final int remotePort;

  PairRequest({
    required this.id,
    required this.deviceName,
    required this.deviceId,
    required this.remote,
    required this.remotePort,
  });
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  HttpServer? _server;
  HttpServer? get server => _server; // NEW PUBLIC GETTER
  String? _currentUserId;
  final _incomingRequestsController = StreamController<PairRequest>.broadcast();
  Stream<PairRequest> get incomingRequests => _incomingRequestsController.stream;

  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  final Uuid _uuid = Uuid();

  // Paired devices stored as Map<String, Map> where key is ip:port
  static const _prefKey = 'paired_devices';

  Future<void> startServer({int port = 5000, required String userId}) async {
    if (_server != null) {
      print('[SyncService] HTTP server já está em execução na porta $port.');
      _currentUserId = userId; // Atualiza o userId caso seja uma reinicialização lógica
      return;
    }
    _currentUserId = userId;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true); // Adicionado shared: true
    _server!.listen(_handleRequest);
    print('[SyncService] HTTP server iniciado em 0.0.0.0:$port para o usuário $_currentUserId (shared).');
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      final path = req.uri.path;
      if (req.method == 'POST' && path == '/pair/request') {
        final payload = await utf8.decoder.bind(req).join();
        final data = json.decode(payload) as Map<String, dynamic>;
        final deviceName = data['deviceName'] as String? ?? 'unknown';
        final deviceId = data['deviceId'] as String? ?? '';
        final requester = req.connectionInfo?.remoteAddress;
        final requesterPort = req.connectionInfo?.remotePort ?? 0;

        final requestId = _uuid.v4();
        final pairReq = PairRequest(
          id: requestId,
          deviceName: deviceName,
          deviceId: deviceId,
          remote: requester ?? InternetAddress.loopbackIPv4,
          remotePort: requesterPort,
        );

        final completer = Completer<Map<String, dynamic>>();
        _pending[requestId] = completer;

        // notify UI
        _incomingRequestsController.add(pairReq);

        // Wait for user's decision (up to 60s)
        Map<String, dynamic> result;
        try {
          result = await completer.future.timeout(Duration(seconds: 60));
        } catch (e) {
          result = {'status': 'timeout'};
        } finally {
          _pending.remove(requestId);
        }

        // Response to client
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(json.encode(result));
        await req.response.close();
      } else if (req.method == 'POST' && path == '/sync') {
        final authHeader = req.headers['Authorization'];
        if (authHeader == null || authHeader.isEmpty) {
          req.response
            ..statusCode = HttpStatus.unauthorized
            ..write('Unauthorized: No Authorization header');
          await req.response.close();
          return;
        }

        final token = authHeader[0].replaceFirst('Bearer ', '');
        final remoteIp = req.connectionInfo!.remoteAddress.address;
        print('[SyncService] Autenticando requisição de IP: $remoteIp com Token: $token');
        final isAuthenticated = await _authenticate(remoteIp, token);

        if (!isAuthenticated) {
          req.response
            ..statusCode = HttpStatus.forbidden
            ..write('Forbidden: Invalid token or not paired');
          await req.response.close();
          return;
        }

        final clientUserId = req.headers.value('X-User-ID');
        if (clientUserId == null) {
          req.response
            ..statusCode = HttpStatus.badRequest
            ..write('Bad Request: Missing X-User-ID header');
          await req.response.close();
          return;
        }

        if (_currentUserId != clientUserId) {
          req.response
            ..statusCode = HttpStatus.conflict
            ..write('Conflict: Client and Server user IDs do not match.');
          await req.response.close();
          return;
        }

        // --- Início da Lógica de Sincronização Bidirecional ---
        try {
          // 1. Receber os dados de backup do cliente
          final clientPayload = await utf8.decoder.bind(req).join();
          final clientBackupData = BackupData.fromMap(json.decode(clientPayload));

          // 2. Exportar os dados de backup do servidor
          final serverBackupData = await DatabaseService.instance.exportBackupData(_currentUserId!);

          // 3. Mesclar os dados do cliente com os dados do servidor
          final mergedBackupData = _mergeBackupData(serverBackupData, clientBackupData);

          // 4. Importar os dados mesclados para o banco de dados do servidor
          await DatabaseService.instance.importMergedData(mergedBackupData, _currentUserId!);

          // 5. Enviar os dados mesclados de volta ao cliente
          final jsonData = json.encode(mergedBackupData.toMap());
          req.response.headers.contentType = ContentType.json;
          req.response.statusCode = HttpStatus.ok;
          req.response.write(jsonData);
          await req.response.close();
          print('[SyncService] Sincronização bidirecional concluída com sucesso.');
        } catch (e, s) {
          print('[SyncService] Erro na sincronização bidirecional: $e');
          print(s);
          req.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Internal Server Error: $e');
          await req.response.close();
        }
        // --- Fim da Lógica de Sincronização Bidirecional ---
      }
      else {
        // Not found
        req.response.statusCode = 404;
        await req.response.close();
      }
    } catch (e) {
      try {
        req.response.statusCode = 500;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<bool> _authenticate(String ip, String token) async {
    final pairedDevices = await getPairedDevices();
    print('[SyncService] Autenticando... Dispositivos pareados salvos: ${json.encode(pairedDevices)}');

    for (var entry in pairedDevices.entries) {
      final device = entry.value as Map<String, dynamic>;
      final savedIp = device['ip'] as String?;
      final savedToken = device['token'] as String?;
      print('[SyncService] Comparando IP recebido ($ip) com salvo ($savedIp) E Token recebido ($token) com salvo ($savedToken)');

      if (savedIp == ip && savedToken == token) {
        print('[SyncService] Autenticação BEM-SUCEDIDA para IP $ip');
        return true;
      }
    }

    print('[SyncService] Autenticação FALHOU para IP $ip');
    return false;
  }

  /// Called by UI when user accepts/rejects an incoming pair request.
  /// If accepted=true, generate token, store pairing, and complete the waiting client.
  Future<void> respondToPairRequest(String requestId, {required bool accepted, String? token, String? nickname}) async {
    final completer = _pending[requestId];
    if (completer == null) return;

    if (!accepted) {
      completer.complete({'status': 'rejected'});
      return;
    }

    final data = {'status': 'accepted', 'token': token};

    // store pairing (we need the request info to know ip/port) -> locate pair request by id
    // We don't keep the PairRequest after completion; better to require UI to call storePairedDevice separately.
    completer.complete(data);
  }

  BackupData _mergeBackupData(BackupData serverData, BackupData clientData) {
    // Helper para mesclar listas de itens com base no ID e lastModified
    List<T> _mergeList<T>(List<T> serverList, List<T> clientList) {
      final Map<String, T> mergedMap = {};

      // Adicionar todos os itens do servidor
      for (final item in serverList) {
        // Tentar acessar 'id' e 'lastModified' dinamicamente
        // Isso assume que todos os modelos em 'data_models.dart' têm 'id' e 'lastModified'
        final id = (item as dynamic).id as String;
        mergedMap[id] = item;
      }

      // Mesclar itens do cliente
      for (final item in clientList) {
        final id = (item as dynamic).id as String;
        final clientLastModified = (item as dynamic).lastModified as int;

        if (mergedMap.containsKey(id)) {
          final serverItem = mergedMap[id];
          final serverLastModified = (serverItem as dynamic).lastModified as int;

          // Last write wins
          if (clientLastModified > serverLastModified) {
            mergedMap[id] = item;
          }
        } else {
          // Item do cliente não existe no servidor, adicionar
          mergedMap[id] = item;
        }
      }

      return mergedMap.values.toList();
    }

    // Mesclar Plans
    final mergedPlans = _mergeList<Plan>(serverData.plans, clientData.plans);

    // Mesclar Subjects
    final mergedSubjects = _mergeList<Subject>(serverData.subjects, clientData.subjects);

    // Mesclar StudyRecords
    final mergedStudyRecords = _mergeList<StudyRecord>(serverData.studyRecords, clientData.studyRecords);

    // Mesclar ReviewRecords
    final mergedReviewRecords = _mergeList<ReviewRecord>(serverData.reviewRecords, clientData.reviewRecords);

    // Mesclar SimuladoRecords
    final mergedSimuladoRecords = _mergeList<SimuladoRecord>(serverData.simuladoRecords, clientData.simuladoRecords);

    // Mesclar PlanningDataPerPlan com base no timestamp "last write wins"
    final Map<String, PlanningBackupData> mergedPlanningDataPerPlan = {};
    mergedPlanningDataPerPlan.addAll(serverData.planningDataPerPlan);

    clientData.planningDataPerPlan.forEach((planId, clientPlanningData) {
      if (mergedPlanningDataPerPlan.containsKey(planId)) {
        final serverPlanningData = mergedPlanningDataPerPlan[planId]!;
        final serverTimestampStr = serverPlanningData.cycleGenerationTimestamp;
        final clientTimestampStr = clientPlanningData.cycleGenerationTimestamp;

        if (clientTimestampStr != null && serverTimestampStr == null) {
          mergedPlanningDataPerPlan[planId] = clientPlanningData;
          return;
        }
        if (clientTimestampStr == null) {
          return;
        }

        try {
          final serverTime = DateTime.parse(serverTimestampStr!);
          final clientTime = DateTime.parse(clientTimestampStr);

          if (clientTime.isAfter(serverTime)) {
            mergedPlanningDataPerPlan[planId] = clientPlanningData;
          }
        } catch (e) {
          // Fallback para cliente ganha em caso de erro de parse, para manter um comportamento previsível
          mergedPlanningDataPerPlan[planId] = clientPlanningData;
          print('Erro ao parsear timestamp do ciclo de planejamento: $e');
        }
      } else {
        mergedPlanningDataPerPlan[planId] = clientPlanningData;
      }
    });


    return BackupData(
      plans: mergedPlans,
      subjects: mergedSubjects,
      studyRecords: mergedStudyRecords,
      reviewRecords: mergedReviewRecords,
      simuladoRecords: mergedSimuladoRecords,
      planningDataPerPlan: mergedPlanningDataPerPlan,
    );
  }

  /// Helper: Server can persist a pairing (called by UI after acceptance)
  Future<void> storePairedDevice(String ip, int port, String token, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    Map<String, dynamic> map = {};
    if (raw != null && raw.isNotEmpty) {
      map = json.decode(raw) as Map<String, dynamic>;
    }
    final key = '$ip:$port';
    map[key] = {'token': token, 'name': name, 'ip': ip, 'port': port};
    await prefs.setString(_prefKey, json.encode(map));
  }

  Future<Map<String, dynamic>> getPairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return {};
    final map = json.decode(raw) as Map<String, dynamic>;
    return map;
  }

  Future<void> removePairedDevice(String ip, int port) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return;
    final map = json.decode(raw) as Map<String, dynamic>;
    final key = '$ip:$port';
    map.remove(key);
    await prefs.setString(_prefKey, json.encode(map));
  }

  /// Client-side: send pair request to remote http server and wait response
  Future<Map<String, dynamic>> sendPairRequest(String ip, int port, String myName, String myId) async {
    final uri = Uri.parse('http://$ip:$port/pair/request');
    try {
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'deviceName': myName, 'deviceId': myId})).timeout(Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        return data;
      } else {
        return {'status': 'error', 'code': resp.statusCode};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<void> clearAllPairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    print('[SyncService] All paired devices have been cleared.');
  }
}