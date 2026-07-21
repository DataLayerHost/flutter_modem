import 'dart:typed_data';

import 'packet.dart';

/// A successfully synchronized and CRC-validated modem frame.
final class ModemFrame {
  const ModemFrame(this.packet);

  final Packet packet;

  Uint8List get payload => packet.payload;
  int get version => packet.version;
}
