// lib/services/mdns_advertiser.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class MdnsAdvertiser {
  RawDatagramSocket? _socket;
  RawDatagramSocket? get socket => _socket; // NEW PUBLIC GETTER
  Timer? _timer;

  final String instanceName; // ex: "Ouroboros-Desktop"
  final String serviceType; // ex: "_ouro._tcp.local"
  final int port; // ex: 8080

  MdnsAdvertiser({
    required this.instanceName,
    required this.serviceType,
    required this.port,
  });

  InternetAddress get multicast => InternetAddress('224.0.0.251');
  int get mdnsPort => 5353;

  Future<void> start() async {
    if (_socket != null) return;

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      mdnsPort,
      reusePort: !Platform.isAndroid, // Desabilita reusePort no Android
      reuseAddress: true,
    );

    _socket!.joinMulticast(multicast);

    _timer = Timer.periodic(Duration(seconds: 2), (_) {
      _sendAnnouncement();
    });

    print("[mDNS] Advertiser started: $instanceName.$serviceType:$port");
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
    _socket = null;
    print("[mDNS] Advertiser stopped");
  }

  void _sendAnnouncement() {
    if (_socket == null) return;

    final ptrName = serviceType;
    final fullInstance = "$instanceName.$serviceType";
    final hostname = "${Platform.localHostname}.local";

    // Use loopback placeholder for payload; discovery clients should connect to discovered IP.
    final ip = InternetAddress.anyIPv4;

    final packet = BytesBuilder();

    // Header
    packet.add(_dnsHeader(answerCount: 4));

    // PTR
    packet.add(_ptrRecord(ptrName, fullInstance));

    // SRV
    packet.add(_srvRecord(fullInstance, hostname, port));

    // TXT (empty)
    packet.add(_txtRecord(fullInstance));

    // A
    packet.add(_aRecord(hostname, ip));

    _socket!.send(packet.toBytes(), multicast, mdnsPort);
  }

  List<int> _dnsHeader({int answerCount = 1}) {
    return [
      0x00, 0x00, // ID
      0x84, 0x00, // Flags
      0x00, 0x00, // QDCOUNT
      0x00, answerCount, // ANCOUNT
      0x00, 0x00, // NSCOUNT
      0x00, 0x00, // ARCOUNT
    ];
  }

  List<int> _ptrRecord(String name, String target) {
    return _makeRecord(name, 12, _encodeName(target)); // PTR = 12
  }

  List<int> _srvRecord(String name, String host, int port) {
    final payload = BytesBuilder();
    payload.add([0x00, 0x00]); // priority
    payload.add([0x00, 0x00]); // weight
    payload.add([(port >> 8) & 0xFF, port & 0xFF]);
    payload.add(_encodeName(host));
    return _makeRecord(name, 33, payload.toBytes()); // SRV = 33
  }

  List<int> _txtRecord(String name) {
    return _makeRecord(name, 16, [0x00]); // TXT = 16 (empty)
  }

  List<int> _aRecord(String name, InternetAddress address) {
    return _makeRecord(name, 1, address.rawAddress); // A = 1
  }

  List<int> _makeRecord(String name, int type, List<int> payload) {
    final nameBytes = _encodeName(name);
    final length = payload.length;
    final record = BytesBuilder();
    record.add(nameBytes);
    record.add([(type >> 8) & 0xFF, type & 0xFF]);
    record.add([0x00, 0x01]); // class IN
    record.add([0x00, 0x3C]); // TTL 60s
    record.add([(length >> 8) & 0xFF, length & 0xFF]);
    record.add(payload);
    return record.toBytes();
  }

  List<int> _encodeName(String name) {
    final parts = name.split('.');
    final bytes = BytesBuilder();
    for (var part in parts) {
      final p = part;
      if (p.isEmpty) continue;
      bytes.add([p.length]);
      bytes.add(p.codeUnits);
    }
    bytes.add([0x00]);
    return bytes.toBytes();
  }
}
