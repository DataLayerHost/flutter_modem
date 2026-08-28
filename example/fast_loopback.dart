import 'dart:convert';

import 'package:flutter_modem/flutter_modem.dart';

void main() {
  final FlutterModem modem = FlutterModem(modulation: const Bfsk.fast());
  final List<int> sent = utf8.encode('Fast acoustic modem');
  final List<ModemFrame> received = modem.createDecoder().feed(
        modem.encode(sent),
      );

  if (received.length != 1 ||
      bytesToHex(received.single.payload) != bytesToHex(sent)) {
    throw StateError('Fast loopback failed.');
  }
  print(utf8.decode(received.single.payload));
}
