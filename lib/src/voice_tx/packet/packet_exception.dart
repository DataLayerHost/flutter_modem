import '../envelope/envelope_exception.dart';

/// A packet encoding or validation failure.
final class VoiceTxPacketException extends VoiceTxException {
  const VoiceTxPacketException(super.error, super.message);
}
