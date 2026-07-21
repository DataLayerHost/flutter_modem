/// CRC-16/CCITT-FALSE (poly 0x1021, init 0xffff, no reflection, xor-out 0).
abstract final class Crc16CcittFalse {
  static int compute(Iterable<int> bytes) {
    int crc = 0xffff;
    for (final int byte in bytes) {
      crc ^= (byte & 0xff) << 8;
      for (int bit = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xffff
            : (crc << 1) & 0xffff;
      }
    }
    return crc;
  }
}
