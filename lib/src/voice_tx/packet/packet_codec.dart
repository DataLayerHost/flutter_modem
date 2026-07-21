import 'dart:typed_data';

import '../checksum/crc32.dart';
import '../envelope/envelope_exception.dart';
import '../util/byte_reader.dart';
import '../util/byte_writer.dart';
import 'packet_exception.dart';
import 'packet_type.dart';
import 'voice_tx_packet.dart';

abstract final class PacketCodec {
  static const int headerLength = 19;
  static const int overhead = 23;

  static Uint8List encode(VoiceTxPacket packet) {
    final payload = packet.payload;
    final writer = ByteWriter(overhead + payload.length)
      ..writeUint8(0x56)
      ..writeUint8(0x54)
      ..writeUint8(packet.protocolVersion)
      ..writeUint8(packet.type.wireValue)
      ..writeUint8(packet.flags)
      ..writeUint64(packet.messageId)
      ..writeUint16(packet.packetIndex)
      ..writeUint16(packet.packetCount)
      ..writeUint16(payload.length)
      ..writeBytes(payload);
    final prefix = Uint8List.fromList(
        writer.prefixForChecksum(overhead + payload.length - 4));
    writer.writeUint32(Crc32.compute(prefix));
    return writer.takeBytes();
  }

  static VoiceTxPacket decode(Uint8List bytes,
      {required int maximumPayloadSize}) {
    if (maximumPayloadSize < 0 || maximumPayloadSize > 0xffff) {
      throw ArgumentError.value(maximumPayloadSize, 'maximumPayloadSize');
    }
    if (bytes.length < overhead) {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.invalidLength, 'Truncated packet');
    }
    try {
      final reader = ByteReader(bytes);
      if (reader.readUint8() != 0x56 || reader.readUint8() != 0x54) {
        throw const VoiceTxPacketException(
            VoiceTxProtocolError.invalidMagic, 'Invalid packet magic');
      }
      final version = reader.readUint8();
      if (version != VoiceTxPacket.currentVersion) {
        throw const VoiceTxPacketException(
            VoiceTxProtocolError.unsupportedVersion,
            'Unsupported packet version');
      }
      final type = VoiceTxPacketType.fromWireValue(reader.readUint8());
      if (type == null) {
        throw const VoiceTxPacketException(
            VoiceTxProtocolError.unexpectedPacketType, 'Unknown packet type');
      }
      final flags = reader.readUint8();
      if (flags != 0) {
        throw const VoiceTxPacketException(
            VoiceTxProtocolError.malformedEnvelope, 'Unknown required flags');
      }
      final messageId = reader.readUint64();
      final index = reader.readUint16();
      final count = reader.readUint16();
      final length = reader.readUint16();
      if (length > maximumPayloadSize) {
        throw const VoiceTxPacketException(VoiceTxProtocolError.payloadTooLarge,
            'Payload exceeds configured maximum');
      }
      if (bytes.length != overhead + length) {
        throw const VoiceTxPacketException(VoiceTxProtocolError.invalidLength,
            'Packet length does not match declaration');
      }
      if (count == 0 || index >= count) {
        throw const VoiceTxPacketException(
            VoiceTxProtocolError.invalidPacketIndex,
            'Invalid packet index or count');
      }
      final payload = reader.readBytes(length);
      final crc = reader.readUint32();
      if (crc != Crc32.compute(bytes, 0, bytes.length - 4)) {
        throw const VoiceTxPacketException(
            VoiceTxProtocolError.invalidCrc, 'Packet CRC mismatch');
      }
      _validateControl(type, payload.length);
      final packet = VoiceTxPacket.decoded(
          protocolVersion: version,
          type: type,
          flags: flags,
          messageId: messageId,
          packetIndex: index,
          packetCount: count,
          payload: payload);
      if (type == VoiceTxPacketType.rejected ||
          type == VoiceTxPacketType.error) {
        packet.protocolError;
        packet.diagnostic;
      }
      return packet;
    } on VoiceTxPacketException {
      rethrow;
    } on FormatException {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.invalidLength, 'Truncated packet');
    }
  }

  static void _validateControl(VoiceTxPacketType type, int length) {
    final valid = switch (type) {
      VoiceTxPacketType.hello ||
      VoiceTxPacketType.ready ||
      VoiceTxPacketType.complete =>
        length == 0,
      VoiceTxPacketType.acknowledgement => length == 2,
      VoiceTxPacketType.negativeAcknowledgement => length == 4,
      VoiceTxPacketType.accepted => length == 32 || length == 34,
      VoiceTxPacketType.rejected ||
      VoiceTxPacketType.error =>
        length >= 2 && length <= 2 + VoiceTxPacket.maximumDiagnosticBytes,
      VoiceTxPacketType.data => true,
    };
    if (!valid) {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.invalidLength, 'Invalid control packet payload');
    }
  }
}
