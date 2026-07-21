import '../envelope/envelope_exception.dart';
import '../packet/packet_type.dart';
import '../packet/voice_tx_packet.dart';
import '../stream/packetizer.dart';
import 'session_event.dart';
import 'session_state.dart';

/// Deterministic half-duplex sender state machine.
final class VoiceTxSenderSession {
  VoiceTxSenderSession(
      {required this.transmission, this.maximumRetriesPerPacket = 3}) {
    if (maximumRetriesPerPacket < 0) {
      throw ArgumentError.value(
          maximumRetriesPerPacket, 'maximumRetriesPerPacket');
    }
  }
  final VoiceTxTransmission transmission;
  final int maximumRetriesPerPacket;
  VoiceTxSenderState state = VoiceTxSenderState.idle;
  int _index = 0;
  int _retries = 0;

  VoiceTxSenderAction start() {
    if (state != VoiceTxSenderState.idle) {
      return _fail(VoiceTxProtocolError.unexpectedPacketType);
    }
    state = VoiceTxSenderState.waitingForReady;
    return SendPacket(VoiceTxPacket.hello(messageId: transmission.messageId));
  }

  VoiceTxSenderAction accept(VoiceTxPacket packet) {
    if (packet.messageId != transmission.messageId) {
      return _fail(VoiceTxProtocolError.inconsistentMessageId);
    }
    if (state == VoiceTxSenderState.waitingForReady &&
        packet.type == VoiceTxPacketType.ready) {
      return _sendCurrent();
    }
    if (state == VoiceTxSenderState.waitingForAcknowledgement) {
      if (packet.type == VoiceTxPacketType.acknowledgement) {
        final acknowledged = packet.acknowledgedPacketIndex;
        if (acknowledged < _index) return const WaitForResponse();
        if (acknowledged != _index) {
          return _fail(VoiceTxProtocolError.invalidPacketIndex);
        }
        _retries = 0;
        _index++;
        if (_index < transmission.packets.length) return _sendCurrent();
        state = VoiceTxSenderState.waitingForFinalResult;
        return SendPacket(
            VoiceTxPacket.complete(messageId: transmission.messageId));
      }
      if (packet.type == VoiceTxPacketType.negativeAcknowledgement) {
        final nack = packet.negativeAcknowledgement;
        if (nack.packetIndex != _index) {
          return _fail(VoiceTxProtocolError.invalidPacketIndex);
        }
        return _retry(nack.error);
      }
    }
    if (state == VoiceTxSenderState.waitingForFinalResult) {
      if (packet.type == VoiceTxPacketType.accepted) {
        final payload = packet.payload;
        if (payload.length != 32 && payload.length != 34) {
          return _fail(VoiceTxProtocolError.invalidLength);
        }
        for (var i = 0; i < 32; i++) {
          if (payload[i] != transmission.transactionHash[i]) {
            return _fail(VoiceTxProtocolError.invalidHash);
          }
        }
        state = VoiceTxSenderState.accepted;
        return TransmissionAccepted(transmission.transactionHash);
      }
      if (packet.type == VoiceTxPacketType.rejected ||
          packet.type == VoiceTxPacketType.error) {
        state = VoiceTxSenderState.rejected;
        return TransmissionRejected(packet.protocolError);
      }
    }
    return _fail(VoiceTxProtocolError.unexpectedPacketType);
  }

  VoiceTxSenderAction onTimeout() {
    if (state == VoiceTxSenderState.waitingForAcknowledgement) {
      return _retry(VoiceTxProtocolError.timeout);
    }
    if (state == VoiceTxSenderState.waitingForReady ||
        state == VoiceTxSenderState.waitingForFinalResult) {
      return _fail(VoiceTxProtocolError.timeout);
    }
    return _fail(VoiceTxProtocolError.unexpectedPacketType);
  }

  VoiceTxSenderAction _sendCurrent() {
    state = VoiceTxSenderState.waitingForAcknowledgement;
    return SendPacket(transmission.packets[_index]);
  }

  VoiceTxSenderAction _retry(VoiceTxProtocolError error) {
    if (_retries >= maximumRetriesPerPacket) return _fail(error);
    _retries++;
    return _sendCurrent();
  }

  VoiceTxSenderAction _fail(VoiceTxProtocolError error) {
    state = VoiceTxSenderState.failed;
    return TransmissionFailed(error);
  }
}
