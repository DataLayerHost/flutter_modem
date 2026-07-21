/// Invokes [writeBit] for each byte, most-significant bit first.
void forEachBit(Iterable<int> bytes, void Function(int bit) writeBit) {
  for (final int byte in bytes) {
    for (int shift = 7; shift >= 0; shift--) {
      writeBit((byte >> shift) & 1);
    }
  }
}

List<int> bytesToBits(Iterable<int> bytes) {
  final List<int> result = <int>[];
  forEachBit(bytes, result.add);
  return result;
}

int bitsToByte(List<int> bits, int offset) {
  int value = 0;
  for (int index = 0; index < 8; index++) {
    value = (value << 1) | (bits[offset + index] & 1);
  }
  return value;
}
