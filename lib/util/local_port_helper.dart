import 'package:flutter/foundation.dart';
import 'package:network_tools/network_tools.dart';

class LocalPortHelper {
  LocalPortHelper._internal();
  static const int startPort = 4444;
  static final ports =
      List.generate(150, (index) => startPort + index, growable: true);
  static final usedPort = [];

  static Future<int> emptyPortScan() async {
    for (int port in ports) {
      try {
        final activeHost = await PortScannerService.instance.isOpen(
            "127.0.0.1", port,
            timeout: const Duration(milliseconds: 150));
        if (activeHost == null) {
          usedPort.add(port);
          ports.remove(port);
          return port;
        }
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    }
    throw Exception("No port available");
  }
}
