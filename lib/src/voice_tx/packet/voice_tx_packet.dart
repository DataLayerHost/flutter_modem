import 'dart:convert';
import 'dart:typed_data';

import '../envelope/envelope_exception.dart';
import '../util/byte_reader.dart';
import '../util/byte_writer.dart';
import 'packet_codec.dart';
import 'packet_exception.dart';
import 'packet_type.dart';

/// Immutable protocol packet.
final class VoiceTxPacket {
  VoiceTxPacket._(
      {required this.protocolVersion,
      required this.type,
      required this.flags,
      required this.messageId,
      required this.packetIndex,
      required this.packetCount,
      required Uint8List payload})
      : _payload = Uint8List.fromList(payload);

  static const int currentVersion = 1;
  static const int protocolMaximumPayloadSize = 0xffff;
  static const int maximumDiagnosticBytes = 96;

  final int protocolVersion;
  final VoiceTxPacketType type;
  final int flags;
  final int messageId;
  final int packetIndex;
  final int packetCount;
  final Uint8List _payload;
  Uint8List get payload => Uint8List.fromList(_payload);

  factory VoiceTxPacket(
      {required VoiceTxPacketType type,
      required int messageId,
      int packetIndex = 0,
      int packetCount = 1,
      Uint8List? payload,
      int flags = 0}) {
    if (messageId < 0 ||
        packetCount < 1 ||
        packetCount > 0xffff ||
        packetIndex < 0 ||
        packetIndex >= packetCount ||
        flags != 0) {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.invalidPacketIndex, 'Invalid packet metadata');
    }
    final body = Uint8List.fromList(payload ?? Uint8List(0));
    if (body.length > protocolMaximumPayloadSize) {
      throw const VoiceTxPacketException(VoiceTxProtocolError.payloadTooLarge,
          'Payload exceeds protocol limit');
    }
    return VoiceTxPacket._(
        protocolVersion: currentVersion,
        type: type,
        flags: flags,
        messageId: messageId,
        packetIndex: packetIndex,
        packetCount: packetCount,
        payload: body);
  }

  factory VoiceTxPacket.hello({required int messageId}) =>
      VoiceTxPacket(type: VoiceTxPacketType.hello, messageId: messageId);
  factory VoiceTxPacket.ready({required int messageId}) =>
      VoiceTxPacket(type: VoiceTxPacketType.ready, messageId: messageId);
  factory VoiceTxPacket.ack(
          {required int messageId, required int packetIndex}) =>
      VoiceTxPacket(
          type: VoiceTxPacketType.acknowledgement,
          messageId: messageId,
          payload: _uint16(packetIndex));
  factory VoiceTxPacket.nack(
      {required int messageId,
      required int packetIndex,
      required VoiceTxProtocolError error}) {
    final writer = ByteWriter(4)
      ..writeUint16(packetIndex)
      ..writeUint16(error.wireValue);
    return VoiceTxPacket(
        type: VoiceTxPacketType.negativeAcknowledgement,
        messageId: messageId,
        payload: writer.takeBytes());
  }
  factory VoiceTxPacket.complete({required int messageId}) =>
      VoiceTxPacket(type: VoiceTxPacketType.complete, messageId: messageId);
  factory VoiceTxPacket.accepted(
      {required int messageId,
      required Uint8List transactionHash,
      int? statusCode}) {
    if (transactionHash.length != 32 ||
        statusCode != null && (statusCode < 0 || statusCode > 0xffff)) {
      throw ArgumentError('Invalid ACCEPTED payload');
    }
    final writer = ByteWriter(statusCode == null ? 32 : 34)
      ..writeBytes(transactionHash);
    if (statusCode != null) writer.writeUint16(statusCode);
    return VoiceTxPacket(
        type: VoiceTxPacketType.accepted,
        messageId: messageId,
        payload: writer.takeBytes());
  }
  factory VoiceTxPacket.rejected(
          {required int messageId,
          required VoiceTxProtocolError error,
          String? diagnostic}) =>
      _errorPacket(VoiceTxPacketType.rejected, messageId, error, diagnostic);
  factory VoiceTxPacket.error(
          {required int messageId,
          required VoiceTxProtocolError error,
          String? diagnostic}) =>
      _errorPacket(VoiceTxPacketType.error, messageId, error, diagnostic);

  static VoiceTxPacket _errorPacket(VoiceTxPacketType type, int messageId,
      VoiceTxProtocolError error, String? diagnostic) {
    final text = diagnostic == null
        ? Uint8List(0)
        : Uint8List.fromList(utf8.encode(diagnostic));
    if (text.length > maximumDiagnosticBytes) {
      throw ArgumentError.value(diagnostic, 'diagnostic',
          'UTF-8 form exceeds $maximumDiagnosticBytes bytes');
    }
    final writer = ByteWriter(2 + text.length)
      ..writeUint16(error.wireValue)
      ..writeBytes(text);
    return VoiceTxPacket(
        type: type, messageId: messageId, payload: writer.takeBytes());
  }

  int get acknowledgedPacketIndex {
    if (type != VoiceTxPacketType.acknowledgement || _payload.length != 2) {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.invalidLength, 'Not a valid ACK');
    }
    return ByteReader(_payload).readUint16();
  }

  ({int packetIndex, VoiceTxProtocolError error}) get negativeAcknowledgement {
    if (type != VoiceTxPacketType.negativeAcknowledgement ||
        _payload.length != 4) {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.invalidLength, 'Not a valid NACK');
    }
    final reader = ByteReader(_payload);
    final index = reader.readUint16();
    final error = VoiceTxProtocolError.fromWireValue(reader.readUint16());
    if (error == null) {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.malformedEnvelope, 'Unknown error code');
    }
    return (packetIndex: index, error: error);
  }

  /// The defensively copied hash carried by an ACCEPTED packet.
  Uint8List get acceptedTransactionHash {
    if (type != VoiceTxPacketType.accepted ||
        (_payload.length != 32 && _payload.length != 34)) {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.invalidLength, 'Not a valid ACCEPTED packet');
    }
    return Uint8List.fromList(_payload.sublist(0, 32));
  }

  /// Optional uint16 status carried by an ACCEPTED packet.
  int? get acceptedStatusCode {
    acceptedTransactionHash;
    return _payload.length == 34
        ? ByteReader(Uint8List.fromList(_payload.sublist(32))).readUint16()
        : null;
  }

  VoiceTxProtocolError get protocolError {
    if ((type != VoiceTxPacketType.rejected &&
            type != VoiceTxPacketType.error) ||
        _payload.length < 2) {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.invalidLength, 'Not an error packet');
    }
    final error =
        VoiceTxProtocolError.fromWireValue(ByteReader(_payload).readUint16());
    if (error == null) {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.malformedEnvelope, 'Unknown error code');
    }
    return error;
  }

  /// Bounded UTF-8 diagnostic carried by REJECTED or ERROR, if present.
  String? get diagnostic {
    protocolError;
    if (_payload.length == 2) return null;
    try {
      return utf8.decode(_payload.sublist(2), allowMalformed: false);
    } on FormatException {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.invalidLength, 'Diagnostic is not valid UTF-8');
    }
  }

  Uint8List encode() => PacketCodec.encode(this);
  static VoiceTxPacket decode(Uint8List bytes,
          {int maximumPayloadSize = 256}) =>
      PacketCodec.decode(bytes, maximumPayloadSize: maximumPayloadSize);
  static VoiceTxPacket decoded(
          {required int protocolVersion,
          required VoiceTxPacketType type,
          required int flags,
          required int messageId,
          required int packetIndex,
          required int packetCount,
          required Uint8List payload}) =>
      VoiceTxPacket._(
          protocolVersion: protocolVersion,
          type: type,
          flags: flags,
          messageId: messageId,
          packetIndex: packetIndex,
          packetCount: packetCount,
          payload: payload);

  @override
  bool operator ==(Object other) =>
      other is VoiceTxPacket &&
      protocolVersion == other.protocolVersion &&
      type == other.type &&
      flags == other.flags &&
      messageId == other.messageId &&
      packetIndex == other.packetIndex &&
      packetCount == other.packetCount &&
      _equal(_payload, other._payload);
  @override
  int get hashCode => Object.hash(protocolVersion, type, flags, messageId,
      packetIndex, packetCount, Object.hashAll(_payload));
  @override
  String toString() =>
      'VoiceTxPacket(type: ${type.name}, messageId: $messageId, index: $packetIndex/$packetCount, payloadLength: ${_payload.length})';
}

Uint8List _uint16(int value) {
  if (value < 0 || value > 0xffff) throw RangeError.range(value, 0, 0xffff);
  return (ByteWriter(2)..writeUint16(value)).takeBytes();
}

bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var index = 0; index < a.length; index++) {
    result |= a[index] ^ b[index];
  }
  return result == 0;
}
