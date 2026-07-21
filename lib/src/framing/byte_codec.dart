import 'dart:typed_data';

abstract final class ByteCodec {
  static int readUint16(Uint8List bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];

  static int readUint32(Uint8List bytes, int offset) =>
      bytes[offset] * 0x1000000 +
      bytes[offset + 1] * 0x10000 +
      bytes[offset + 2] * 0x100 +
      bytes[offset + 3];

  static void writeUint16(Uint8List bytes, int offset, int value) {
    bytes[offset] = value >>> 8;
    bytes[offset + 1] = value;
  }

  static void writeUint32(Uint8List bytes, int offset, int value) {
    bytes[offset] = value >>> 24;
    bytes[offset + 1] = value >>> 16;
    bytes[offset + 2] = value >>> 8;
    bytes[offset + 3] = value;
  }
}
