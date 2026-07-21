import '../envelope/envelope_exception.dart';
import '../envelope/transaction_envelope.dart';
import '../packet/packet_type.dart';
import '../packet/voice_tx_packet.dart';
import '../stream/assembly_event.dart';
import '../stream/packet_assembler.dart';
import 'session_event.dart';
import 'session_state.dart';

/// Deterministic receiver state machine; it performs no I/O or broadcasting.
final class VoiceTxReceiverSession {
  VoiceTxReceiverSession({required this.assembler});
  final VoiceTxPacketAssembler assembler;
  VoiceTxReceiverState state = VoiceTxReceiverState.waitingForHello;
  int? _messageId;
  VoiceTxEnvelope? _completedEnvelope;

  List<VoiceTxReceiverAction> accept(VoiceTxPacket packet) {
    if (_messageId != null && packet.messageId != _messageId) {
      return _reject(
          packet.messageId, VoiceTxProtocolError.inconsistentMessageId);
    }
    if (state == VoiceTxReceiverState.waitingForHello) {
      if (packet.type != VoiceTxPacketType.hello) {
        return _reject(
            packet.messageId, VoiceTxProtocolError.unexpectedPacketType);
      }
      _messageId = packet.messageId;
      state = VoiceTxReceiverState.receiving;
      return <VoiceTxReceiverAction>[
        SendResponsePacket(VoiceTxPacket.ready(messageId: packet.messageId))
      ];
    }
    if (state == VoiceTxReceiverState.validating &&
        packet.type == VoiceTxPacketType.complete) {
      return _complete(_completedEnvelope!);
    }
    if (state != VoiceTxReceiverState.receiving) {
      return _reject(
          packet.messageId, VoiceTxProtocolError.unexpectedPacketType);
    }
    if (packet.type == VoiceTxPacketType.complete) {
      if (!assembler.isComplete) {
        return _reject(
            packet.messageId, VoiceTxProtocolError.incompleteTransmission);
      }
      return const <VoiceTxReceiverAction>[];
    }
    if (packet.type != VoiceTxPacketType.data) {
      return _reject(
          packet.messageId, VoiceTxProtocolError.unexpectedPacketType);
    }
    final event = assembler.accept(packet);
    return switch (event) {
      VoiceTxPacketAccepted() ||
      VoiceTxDuplicatePacket() =>
        <VoiceTxReceiverAction>[
          SendResponsePacket(VoiceTxPacket.ack(
              messageId: packet.messageId, packetIndex: packet.packetIndex))
        ],
      VoiceTxPacketRejected(:final error) => <VoiceTxReceiverAction>[
          SendResponsePacket(VoiceTxPacket.nack(
              messageId: packet.messageId,
              packetIndex: packet.packetIndex,
              error: error))
        ],
      VoiceTxTransactionComplete(:final envelope) =>
        _validated(packet, envelope),
    };
  }

  List<VoiceTxReceiverAction> _validated(
      VoiceTxPacket packet, VoiceTxEnvelope envelope) {
    _completedEnvelope = envelope;
    state = VoiceTxReceiverState.validating;
    return <VoiceTxReceiverAction>[
      SendResponsePacket(VoiceTxPacket.ack(
          messageId: packet.messageId, packetIndex: packet.packetIndex))
    ];
  }

  List<VoiceTxReceiverAction> _complete(VoiceTxEnvelope envelope) {
    state = VoiceTxReceiverState.complete;
    return <VoiceTxReceiverAction>[
      ReceiverTransactionComplete(envelope),
      SendResponsePacket(VoiceTxPacket.accepted(
          messageId: envelope.messageId,
          transactionHash: envelope.transactionHash)),
      const TerminateReceiverSession(null)
    ];
  }

  List<VoiceTxReceiverAction> _reject(
      int messageId, VoiceTxProtocolError error) {
    state = VoiceTxReceiverState.rejected;
    return <VoiceTxReceiverAction>[
      SendResponsePacket(
          VoiceTxPacket.rejected(messageId: messageId, error: error)),
      TerminateReceiverSession(error)
    ];
  }
}
