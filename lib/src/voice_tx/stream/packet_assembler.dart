import 'dart:typed_data';

import '../envelope/envelope_exception.dart';
import '../envelope/transaction_envelope.dart';
import '../packet/packet_type.dart';
import '../packet/voice_tx_packet.dart';
import 'assembly_event.dart';

/// Bounded, out-of-order DATA packet assembler.
final class VoiceTxPacketAssembler {
  VoiceTxPacketAssembler(
      {this.maximumTransactionSize = 4096,
      this.maximumPacketCount = 256,
      this.maximumPacketPayloadSize = 64,
      int? maximumBufferedBytes})
      : maximumBufferedBytes =
            maximumBufferedBytes ?? maximumTransactionSize + 58 {
    if (maximumTransactionSize < 1 ||
        maximumPacketCount < 1 ||
        maximumPacketCount > 0xffff ||
        maximumPacketPayloadSize < 1 ||
        this.maximumBufferedBytes < 1) {
      throw ArgumentError('Assembler limits must be positive and bounded');
    }
  }
  final int maximumTransactionSize;
  final int maximumPacketCount;
  final int maximumPacketPayloadSize;
  final int maximumBufferedBytes;
  final Map<int, Uint8List> _payloads = <int, Uint8List>{};
  int? _messageId;
  int? _packetCount;
  int _bufferedBytes = 0;
  bool _complete = false;

  int get receivedPacketCount => _payloads.length;
  int? get totalPacketCount => _packetCount;
  int get bufferedByteCount => _bufferedBytes;
  double get progress =>
      _packetCount == null ? 0 : _payloads.length / _packetCount!;
  bool get isComplete => _complete;

  VoiceTxAssemblyEvent accept(VoiceTxPacket packet) {
    if (packet.type != VoiceTxPacketType.data) {
      return VoiceTxPacketRejected(VoiceTxProtocolError.unexpectedPacketType,
          packetIndex: packet.packetIndex);
    }
    if (packet.payload.length > maximumPacketPayloadSize) {
      return VoiceTxPacketRejected(VoiceTxProtocolError.payloadTooLarge,
          packetIndex: packet.packetIndex);
    }
    if (packet.packetCount > maximumPacketCount) {
      return VoiceTxPacketRejected(VoiceTxProtocolError.packetCountTooLarge,
          packetIndex: packet.packetIndex);
    }
    if (packet.packetIndex >= packet.packetCount) {
      return VoiceTxPacketRejected(VoiceTxProtocolError.invalidPacketIndex,
          packetIndex: packet.packetIndex);
    }
    if (_messageId != null && packet.messageId != _messageId) {
      return VoiceTxPacketRejected(VoiceTxProtocolError.inconsistentMessageId,
          packetIndex: packet.packetIndex);
    }
    if (_packetCount != null && packet.packetCount != _packetCount) {
      return VoiceTxPacketRejected(VoiceTxProtocolError.inconsistentPacketCount,
          packetIndex: packet.packetIndex);
    }
    final payload = packet.payload;
    final existing = _payloads[packet.packetIndex];
    if (existing != null) {
      return _equal(existing, payload)
          ? VoiceTxDuplicatePacket(packet.packetIndex)
          : VoiceTxPacketRejected(VoiceTxProtocolError.conflictingDuplicate,
              packetIndex: packet.packetIndex);
    }
    if (_bufferedBytes + payload.length > maximumBufferedBytes) {
      return VoiceTxPacketRejected(VoiceTxProtocolError.payloadTooLarge,
          packetIndex: packet.packetIndex);
    }
    _messageId ??= packet.messageId;
    _packetCount ??= packet.packetCount;
    _payloads[packet.packetIndex] = Uint8List.fromList(payload);
    _bufferedBytes += payload.length;
    if (_payloads.length != _packetCount) {
      return VoiceTxPacketAccepted(
          packetIndex: packet.packetIndex,
          receivedPacketCount: _payloads.length,
          totalPacketCount: _packetCount!);
    }
    final builder = BytesBuilder(copy: false);
    for (var index = 0; index < _packetCount!; index++) {
      final part = _payloads[index];
      if (part == null) {
        return VoiceTxPacketRejected(
            VoiceTxProtocolError.incompleteTransmission,
            packetIndex: packet.packetIndex);
      }
      builder.add(part);
    }
    try {
      final envelope = VoiceTxEnvelope.decode(builder.takeBytes(),
          maximumTransactionSize: maximumTransactionSize);
      if (envelope.messageId != _messageId) {
        return VoiceTxPacketRejected(VoiceTxProtocolError.inconsistentMessageId,
            packetIndex: packet.packetIndex);
      }
      _complete = true;
      return VoiceTxTransactionComplete(
          envelope: envelope, transaction: envelope.transaction);
    } on VoiceTxEnvelopeException catch (error) {
      return VoiceTxPacketRejected(error.error,
          packetIndex: packet.packetIndex);
    }
  }

  void reset() {
    _payloads.clear();
    _messageId = null;
    _packetCount = null;
    _bufferedBytes = 0;
    _complete = false;
  }
}

bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var value = 0;
  for (var index = 0; index < a.length; index++) {
    value |= a[index] ^ b[index];
  }
  return value == 0;
}
