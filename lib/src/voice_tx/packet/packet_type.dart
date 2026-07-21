/// Stable packet types for protocol version 1.
enum VoiceTxPacketType {
  hello(1),
  ready(2),
  data(3),
  acknowledgement(4),
  negativeAcknowledgement(5),
  complete(6),
  accepted(7),
  rejected(8),
  error(9);

  const VoiceTxPacketType(this.wireValue);
  final int wireValue;

  static VoiceTxPacketType? fromWireValue(int value) {
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}
