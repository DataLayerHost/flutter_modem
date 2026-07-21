import 'dart:convert';

import 'package:dart_modem/dart_modem.dart';

void main() {
  final DartModem modem = DartModem(modulation: const Bfsk.fast());
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
