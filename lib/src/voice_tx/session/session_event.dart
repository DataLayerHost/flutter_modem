import 'dart:typed_data';

import '../envelope/envelope_exception.dart';
import '../packet/voice_tx_packet.dart';
import '../envelope/transaction_envelope.dart';

/// An I/O-free action emitted by a sender session.
sealed class VoiceTxSenderAction {
  const VoiceTxSenderAction();
}

final class SendPacket extends VoiceTxSenderAction {
  const SendPacket(this.packet);
  final VoiceTxPacket packet;
}

final class WaitForResponse extends VoiceTxSenderAction {
  const WaitForResponse();
}

final class TransmissionAccepted extends VoiceTxSenderAction {
  TransmissionAccepted(Uint8List transactionHash)
      : _transactionHash = Uint8List.fromList(transactionHash);
  final Uint8List _transactionHash;
  Uint8List get transactionHash => Uint8List.fromList(_transactionHash);
}

final class TransmissionRejected extends VoiceTxSenderAction {
  const TransmissionRejected(this.error);
  final VoiceTxProtocolError error;
}

final class TransmissionFailed extends VoiceTxSenderAction {
  const TransmissionFailed(this.error);
  final VoiceTxProtocolError error;
}

/// An I/O-free action emitted by a receiver session.
sealed class VoiceTxReceiverAction {
  const VoiceTxReceiverAction();
}

final class SendResponsePacket extends VoiceTxReceiverAction {
  const SendResponsePacket(this.packet);
  final VoiceTxPacket packet;
}

final class ReceiverTransactionComplete extends VoiceTxReceiverAction {
  const ReceiverTransactionComplete(this.envelope);
  final VoiceTxEnvelope envelope;
}

final class TerminateReceiverSession extends VoiceTxReceiverAction {
  const TerminateReceiverSession(this.error);
  final VoiceTxProtocolError? error;
}
