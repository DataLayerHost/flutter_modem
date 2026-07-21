import 'dart:typed_data';

/// IEEE 802.3 CRC-32 used by protocol version 1.
abstract final class Crc32 {
  static const int _polynomial = 0xedb88320;

  /// Computes an unsigned CRC-32.
  static int compute(Uint8List bytes, [int start = 0, int? end]) {
    final stop = end ?? bytes.length;
    var crc = 0xffffffff;
    for (var index = start; index < stop; index++) {
      crc ^= bytes[index];
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >>> 1) ^ ((crc & 1) == 0 ? 0 : _polynomial);
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}
