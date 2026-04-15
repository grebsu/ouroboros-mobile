import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
  HttpServer? get server => _server;
  String? _currentUserId;
  final _incomingRequestsController = StreamController<PairRequest>.broadcast();
  Stream<PairRequest> get incomingRequests => _incomingRequestsController.stream;

  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  final Uuid _uuid = const Uuid();

  static const _prefKey = 'paired_devices';

  Future<void> startServer({int port = 5000, required String userId}) async {
    if (_server != null) {
      debugPrint('[SyncService] HTTP server já está em execução na porta $port.');
      _currentUserId = userId;
      return;
    }
    _currentUserId = userId;
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    _server!.listen(_handleRequest);
    debugPrint(
      '[SyncService] HTTP server iniciado em 0.0.0.0:$port para o usuário $_currentUserId (shared).',
    );
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

        _incomingRequestsController.add(pairReq);

        Map<String, dynamic> result;
        try {
          result = await completer.future.timeout(const Duration(seconds: 60));
        } catch (e) {
          result = {'status': 'timeout'};
        } finally {
          _pending.remove(requestId);
        }

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
        debugPrint(
          '[SyncService] Autenticando requisição de IP: $remoteIp com Token: $token',
        );
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

        try {
          final clientPayload = await utf8.decoder.bind(req).join();
          final clientBackupData = BackupData.fromMap(
            json.decode(clientPayload) as Map<String, dynamic>,
          );

          final serverBackupData = await DatabaseService.instance
              .exportBackupData(_currentUserId!);

          final mergedBackupData = _mergeBackupData(
            serverBackupData,
            clientBackupData,
          );

          await DatabaseService.instance.importMergedData(
            mergedBackupData,
            _currentUserId!,
          );

          final jsonData = json.encode(mergedBackupData.toMap());
          req.response.headers.contentType = ContentType.json;
          req.response.statusCode = HttpStatus.ok;
          req.response.write(jsonData);
          await req.response.close();
          debugPrint(
            '[SyncService] Sincronização bidirecional concluída com sucesso.',
          );
        } catch (e, s) {
          debugPrint('[SyncService] Erro na sincronização bidirecional: $e');
          debugPrint('$s');
          req.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Internal Server Error: $e');
          await req.response.close();
        }
      } else {
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
    debugPrint(
      '[SyncService] Autenticando... Dispositivos pareados salvos: ${json.encode(pairedDevices)}',
    );

    for (final entry in pairedDevices.entries) {
      final device = entry.value as Map<String, dynamic>;
      final savedIp = device['ip'] as String?;
      final savedToken = device['token'] as String?;
      debugPrint(
        '[SyncService] Comparando IP recebido ($ip) com salvo ($savedIp) E Token recebido ($token) com salvo ($savedToken)',
      );

      if (savedIp == ip && savedToken == token) {
        debugPrint('[SyncService] Autenticação BEM-SUCEDIDA para IP $ip');
        return true;
      }
    }

    debugPrint('[SyncService] Autenticação FALHOU para IP $ip');
    return false;
  }

  Future<void> respondToPairRequest(
    String requestId, {
    required bool accepted,
    String? token,
    String? nickname,
  }) async {
    final completer = _pending[requestId];
    if (completer == null) return;

    if (!accepted) {
      completer.complete({'status': 'rejected'});
      return;
    }

    final data = {'status': 'accepted', 'token': token};
    completer.complete(data);
  }

  BackupData _mergeBackupData(BackupData serverData, BackupData clientData) {
    List<T> _mergeList<T>(List<T> serverList, List<T> clientList) {
      final Map<String, T> mergedMap = {};

      for (final item in serverList) {
        final id = (item as dynamic).id as String;
        mergedMap[id] = item;
      }

      for (final item in clientList) {
        final id = (item as dynamic).id as String;
        final clientLastModified = (item as dynamic).lastModified as int;

        if (mergedMap.containsKey(id)) {
          final serverItem = mergedMap[id];
          final serverLastModified = (serverItem as dynamic).lastModified as int;

          if (clientLastModified > serverLastModified) {
            mergedMap[id] = item;
          }
        } else {
          mergedMap[id] = item;
        }
      }

      return mergedMap.values.toList();
    }

    final mergedPlans = _mergeList<Plan>(serverData.plans, clientData.plans);
    final mergedSubjects = _mergeList<Subject>(
      serverData.subjects,
      clientData.subjects,
    );
    final mergedStudyRecords = _mergeList<StudyRecord>(
      serverData.studyRecords,
      clientData.studyRecords,
    );
    final mergedReviewRecords = _mergeList<ReviewRecord>(
      serverData.reviewRecords,
      clientData.reviewRecords,
    );
    final mergedSimuladoRecords = _mergeList<SimuladoRecord>(
      serverData.simuladoRecords,
      clientData.simuladoRecords,
    );

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
          mergedPlanningDataPerPlan[planId] = clientPlanningData;
          debugPrint('Erro ao parsear timestamp do ciclo de planejamento: $e');
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

  Future<void> storePairedDevice(
    String ip,
    int port,
    String token,
    String name,
  ) async {
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

  Future<Map<String, dynamic>> sendPairRequest(
    String ip,
    int port,
    String myName,
    String myId,
  ) async {
    final uri = Uri.parse('http://$ip:$port/pair/request');
    try {
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'deviceName': myName, 'deviceId': myId}),
          )
          .timeout(const Duration(seconds: 30));
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
    debugPrint('[SyncService] All paired devices have been cleared.');
  }
}
