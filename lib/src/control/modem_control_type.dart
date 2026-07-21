/// Stable control-frame wire values. New values must only be appended.
enum ModemControlType {
  ready(0x01),
  acknowledgement(0x02),
  negativeAcknowledgement(0x03),
  accepted(0x04),
  rejected(0x05),
  error(0x06);

  const ModemControlType(this.wireValue);

  final int wireValue;

  static ModemControlType? fromWireValue(int value) {
    for (final ModemControlType type in values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return null;
  }
}
