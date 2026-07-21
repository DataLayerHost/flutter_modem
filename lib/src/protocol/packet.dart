import 'dart:typed_data';

import '../util/bytes.dart';
import 'crc32.dart';

/// Binary packet carried inside an acoustic frame.
final class Packet {
  Packet(List<int> payload, {this.version = currentVersion})
      : payload = Uint8List.fromList(payload);

  static const List<int> magic = <int>[0x44, 0x4d, 0x4f, 0x44]; // DMOD
  static const int currentVersion = 1;
  static const int headerLength = 9;
  static const int crcLength = 4;

  final int version;
  final Uint8List payload;

  Uint8List encode() {
    if (payload.length > 0xffffffff) {
      throw const FormatException(
          'Payload is too large for the packet format.');
    }
    final Uint8List result =
        Uint8List(headerLength + payload.length + crcLength);
    result.setRange(0, magic.length, magic);
    result[4] = version;
    writeUint32BigEndian(result, 5, payload.length);
    result.setRange(headerLength, headerLength + payload.length, payload);
    writeUint32BigEndian(
      result,
      headerLength + payload.length,
      Crc32.compute(result.getRange(0, headerLength + payload.length)),
    );
    return result;
  }

  static Packet decode(List<int> bytes,
      {int maximumPayloadLength = 1024 * 1024}) {
    if (bytes.length < headerLength + crcLength) {
      throw const FormatException('Packet is truncated.');
    }
    for (int index = 0; index < magic.length; index++) {
      if (bytes[index] != magic[index]) {
        throw const FormatException('Invalid packet magic.');
      }
    }
    final int version = bytes[4];
    if (version != currentVersion) {
      throw FormatException('Unsupported packet version: $version.');
    }
    final int payloadLength = readUint32BigEndian(bytes, 5);
    if (payloadLength > maximumPayloadLength) {
      throw const FormatException(
          'Packet payload exceeds the configured limit.');
    }
    final int expectedLength = headerLength + payloadLength + crcLength;
    if (bytes.length != expectedLength) {
      throw const FormatException('Packet length does not match its header.');
    }
    final int expectedCrc =
        readUint32BigEndian(bytes, expectedLength - crcLength);
    final int actualCrc =
        Crc32.compute(bytes.getRange(0, expectedLength - crcLength));
    if (expectedCrc != actualCrc) {
      throw const FormatException('Packet CRC-32 validation failed.');
    }
    return Packet(
      bytes.sublist(headerLength, headerLength + payloadLength),
      version: version,
    );
  }
}
