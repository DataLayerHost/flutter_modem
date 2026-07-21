import 'dart:typed_data';

/// IEEE CRC-32 (polynomial 0xEDB88320), as used by Ethernet and gzip.
abstract final class Crc32 {
  static final Uint32List _table = _createTable();

  static int compute(Iterable<int> bytes) {
    int crc = 0xffffffff;
    for (final int byte in bytes) {
      crc = _table[(crc ^ byte) & 0xff] ^ (crc >>> 8);
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  static Uint32List _createTable() {
    final Uint32List table = Uint32List(256);
    for (int index = 0; index < table.length; index++) {
      int value = index;
      for (int bit = 0; bit < 8; bit++) {
        value = (value & 1) == 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
      }
      table[index] = value;
    }
    return table;
  }
}
