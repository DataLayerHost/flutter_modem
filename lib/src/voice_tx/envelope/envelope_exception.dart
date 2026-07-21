/// Stable protocol error identifiers and wire codes.
enum VoiceTxProtocolError {
  unsupportedVersion(1),
  invalidMagic(2),
  invalidLength(3),
  invalidCrc(4),
  invalidHash(5),
  payloadTooLarge(6),
  packetCountTooLarge(7),
  invalidPacketIndex(8),
  inconsistentMessageId(9),
  inconsistentPacketCount(10),
  conflictingDuplicate(11),
  incompleteTransmission(12),
  malformedEnvelope(13),
  unexpectedPacketType(14),
  timeout(15),
  internalError(16);

  const VoiceTxProtocolError(this.wireValue);
  final int wireValue;

  static VoiceTxProtocolError? fromWireValue(int value) {
    for (final error in values) {
      if (error.wireValue == value) return error;
    }
    return null;
  }
}

/// Base class for typed protocol failures.
abstract class VoiceTxException implements Exception {
  const VoiceTxException(this.error, this.message);
  final VoiceTxProtocolError error;
  final String message;

  @override
  String toString() => '$runtimeType: ${error.name}: $message';
}

/// A transaction-envelope validation failure.
final class VoiceTxEnvelopeException extends VoiceTxException {
  const VoiceTxEnvelopeException(super.error, super.message);
}
