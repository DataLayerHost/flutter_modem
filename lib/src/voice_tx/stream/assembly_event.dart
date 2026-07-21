import 'dart:typed_data';

import '../envelope/envelope_exception.dart';
import '../envelope/transaction_envelope.dart';
import '../packet/voice_tx_packet.dart';

/// Result of offering one packet to an assembler.
sealed class VoiceTxAssemblyEvent {
  const VoiceTxAssemblyEvent();
}

final class VoiceTxPacketAccepted extends VoiceTxAssemblyEvent {
  const VoiceTxPacketAccepted(
      {required this.packetIndex,
      required this.receivedPacketCount,
      required this.totalPacketCount});
  final int packetIndex;
  final int receivedPacketCount;
  final int totalPacketCount;
}

final class VoiceTxDuplicatePacket extends VoiceTxAssemblyEvent {
  const VoiceTxDuplicatePacket(this.packetIndex);
  final int packetIndex;
}

final class VoiceTxPacketRejected extends VoiceTxAssemblyEvent {
  const VoiceTxPacketRejected(this.error, {this.packetIndex});
  final VoiceTxProtocolError error;
  final int? packetIndex;
}

final class VoiceTxTransactionComplete extends VoiceTxAssemblyEvent {
  VoiceTxTransactionComplete(
      {required this.envelope, required Uint8List transaction})
      : _transaction = Uint8List.fromList(transaction);
  final VoiceTxEnvelope envelope;
  final Uint8List _transaction;
  Uint8List get transaction => Uint8List.fromList(_transaction);
}

/// Non-fatal streaming parser output.
sealed class VoiceTxStreamEvent {
  const VoiceTxStreamEvent();
}

final class VoiceTxStreamPacket extends VoiceTxStreamEvent {
  const VoiceTxStreamPacket(this.packet);
  final VoiceTxPacket packet;
}

final class VoiceTxStreamError extends VoiceTxStreamEvent {
  const VoiceTxStreamError(this.error);
  final VoiceTxProtocolError error;
}
