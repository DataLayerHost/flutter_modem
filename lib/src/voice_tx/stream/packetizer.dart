import 'dart:collection';
import 'dart:typed_data';

import '../envelope/envelope_exception.dart';
import '../envelope/transaction_envelope.dart';
import '../packet/packet_codec.dart';
import '../packet/packet_exception.dart';
import '../packet/packet_type.dart';
import '../packet/voice_tx_packet.dart';

/// Immutable output of packetization.
final class VoiceTxTransmission {
  VoiceTxTransmission(
      {required this.messageId,
      required Uint8List encodedEnvelope,
      required Uint8List transactionHash,
      required List<VoiceTxPacket> packets})
      : _encodedEnvelope = Uint8List.fromList(encodedEnvelope),
        _transactionHash = Uint8List.fromList(transactionHash),
        packets = UnmodifiableListView<VoiceTxPacket>(
            List<VoiceTxPacket>.unmodifiable(packets));
  final int messageId;
  final Uint8List _encodedEnvelope;
  final Uint8List _transactionHash;
  final List<VoiceTxPacket> packets;
  Uint8List get encodedEnvelope => Uint8List.fromList(_encodedEnvelope);
  Uint8List get transactionHash => Uint8List.fromList(_transactionHash);
  int get totalPacketCount => packets.length;
  int get totalWireByteCount => packets.fold(
      0, (sum, packet) => sum + PacketCodec.overhead + packet.payload.length);
}

/// Splits an envelope into deterministic DATA packets.
final class VoiceTxPacketizer {
  VoiceTxPacketizer({this.maximumPayloadSize = 24}) {
    if (maximumPayloadSize < 1 ||
        maximumPayloadSize > VoiceTxPacket.protocolMaximumPayloadSize) {
      throw ArgumentError.value(maximumPayloadSize, 'maximumPayloadSize');
    }
  }
  final int maximumPayloadSize;

  VoiceTxTransmission packetize(VoiceTxEnvelope envelope) {
    final encoded = envelope.encode();
    final count =
        (encoded.length + maximumPayloadSize - 1) ~/ maximumPayloadSize;
    if (count > 0xffff) {
      throw const VoiceTxPacketException(
          VoiceTxProtocolError.packetCountTooLarge,
          'Packet count exceeds uint16');
    }
    final packets = <VoiceTxPacket>[];
    for (var index = 0; index < count; index++) {
      final start = index * maximumPayloadSize;
      final end = (start + maximumPayloadSize).clamp(0, encoded.length);
      packets.add(VoiceTxPacket(
          type: VoiceTxPacketType.data,
          messageId: envelope.messageId,
          packetIndex: index,
          packetCount: count,
          payload: Uint8List.fromList(encoded.sublist(start, end))));
    }
    return VoiceTxTransmission(
        messageId: envelope.messageId,
        encodedEnvelope: encoded,
        transactionHash: envelope.transactionHash,
        packets: packets);
  }
}
