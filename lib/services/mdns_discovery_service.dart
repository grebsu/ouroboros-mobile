// lib/services/mdns_discovery_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

class MDNSDiscoveryService {
  static final MDNSDiscoveryService _instance =
      MDNSDiscoveryService._internal();
  factory MDNSDiscoveryService() => _instance;
  MDNSDiscoveryService._internal();

  MDnsClient? _mdnsClient;
  final List<StreamSubscription> _subscriptions = [];
  String? _serviceType;
  int? _servicePort;
  String? _instanceName;
  InternetAddress? _serverAddress;

  Function(String serviceName, String ipAddress, int port)? _onDeviceFound;
  Function(String serviceName, String ipAddress)? _onDeviceLost;

  void setOnDeviceFound(
    Function(String serviceName, String ipAddress, int port) callback,
  ) {
    _onDeviceFound = callback;
  }

  void setOnDeviceLost(
    Function(String serviceName, String ipAddress) callback,
  ) {
    _onDeviceLost = callback;
  }

  void init(
    String serviceType,
    int servicePort,
    String instanceName, {
    InternetAddress? serverAddress,
  }) {
    _serviceType = serviceType;
    _servicePort = servicePort;
    _instanceName = instanceName;
    _serverAddress = serverAddress;
  }

  void _log(String msg) {
    if (kDebugMode) print('[MDNSDiscovery] $msg');
  }

  Future<void> _initializeClient() async {
    if (_mdnsClient != null) {
      _mdnsClient!.stop();
      _mdnsClient = null;
    }
    _mdnsClient = MDnsClient(
      rawDatagramSocketFactory:
          (
            dynamic host,
            int port, {
            bool? reuseAddress,
            bool? reusePort,
            int? ttl,
          }) {
            return RawDatagramSocket.bind(
              host,
              port,
              reuseAddress: true,
              reusePort: !Platform.isAndroid,
              ttl: 255,
            ); // Desabilita reusePort no Android
          },
    );
    await _mdnsClient!.start();
  }

  Future<void> _cancelSubscriptions() async {
    for (final s in _subscriptions) {
      try {
        await s.cancel();
      } catch (_) {}
    }
    _subscriptions.clear();
  }

  Future<void> stop() async {
    await _cancelSubscriptions();
    if (_mdnsClient != null) {
      _mdnsClient!.stop();
      _mdnsClient = null;
    }
  }

  Future<void> startDiscovery() async {
    if (_serviceType == null) throw StateError('init first');
    await stop();
    await _initializeClient();
    final nameWithLocal = _serviceType!.endsWith('.local')
        ? _serviceType!
        : '$_serviceType.local';
    _log('Start discovery for $nameWithLocal');

    final ptrStream = _mdnsClient!.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(nameWithLocal),
    );

    final ptrSub = ptrStream.listen(
      (PtrResourceRecord ptr) {
        try {
          final fullDomain = ptr.domainName;
          String instance = fullDomain;
          if (instance.endsWith(nameWithLocal)) {
            instance = instance.substring(
              0,
              instance.length - nameWithLocal.length,
            );
            instance = instance.replaceAll(RegExp(r'\.$'), '');
          }

          final srvStream = _mdnsClient!.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(fullDomain),
          );

          final srvSub = srvStream.listen(
            (SrvResourceRecord srv) {
              final target = srv.target;
              final port = srv.port;
              bool reported = false;

              final aSub = _mdnsClient!
                  .lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv4(target),
                  )
                  .listen(
                    (IPAddressResourceRecord aRec) {
                      final ip = aRec.address?.address ?? '';
                      if (!reported) {
                        reported = true;
                        if (!(instance ==
                                Platform.localHostname.split('.').first &&
                            ip ==
                                (_serverAddress ?? InternetAddress.loopbackIPv4)
                                    .address)) {
                          _onDeviceFound?.call(instance, ip, port);
                        }
                      }
                    },
                    onError: (e) {
                      _log('A lookup error: $e');
                    },
                  );

              final aaaaSub = _mdnsClient!
                  .lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv6(target),
                  )
                  .listen(
                    (IPAddressResourceRecord aRec) {
                      final ip = aRec.address?.address ?? '';
                      if (!reported) {
                        reported = true;
                        _onDeviceFound?.call(instance, ip, port);
                      }
                    },
                    onError: (e) {
                      _log('AAAA lookup error: $e');
                    },
                  );

              _subscriptions.addAll([aSub, aaaaSub]);
            },
            onError: (e) {
              _log('SRV lookup error: $e');
            },
          );

          _subscriptions.add(srvSub);
        } catch (e) {
          _log('PTR processing error: $e');
        }
      },
      onError: (err) {
        _log('PTR stream error: $err');
      },
    );

    _subscriptions.add(ptrSub);
  }

  Future<void> stopDiscovery() async {
    await stop();
  }
}
