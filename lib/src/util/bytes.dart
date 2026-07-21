import 'dart:typed_data';

Uint8List hexToBytes(String hex) {
  final String normalized = hex.replaceAll(RegExp(r'\s+'), '');
  if (normalized.length.isOdd ||
      !RegExp(r'^[0-9a-fA-F]*$').hasMatch(normalized)) {
    throw const FormatException(
        'Expected an even number of hexadecimal digits.');
  }
  final Uint8List result = Uint8List(normalized.length ~/ 2);
  for (int index = 0; index < result.length; index++) {
    result[index] =
        int.parse(normalized.substring(index * 2, index * 2 + 2), radix: 16);
  }
  return result;
}

String bytesToHex(Iterable<int> bytes, {bool uppercase = false}) {
  final String value = bytes
      .map((int byte) => (byte & 0xff).toRadixString(16).padLeft(2, '0'))
      .join();
  return uppercase ? value.toUpperCase() : value;
}

int readUint32BigEndian(List<int> bytes, int offset) =>
    ((bytes[offset] & 0xff) << 24) |
    ((bytes[offset + 1] & 0xff) << 16) |
    ((bytes[offset + 2] & 0xff) << 8) |
    (bytes[offset + 3] & 0xff);

void writeUint32BigEndian(Uint8List bytes, int offset, int value) {
  bytes[offset] = value >>> 24;
  bytes[offset + 1] = value >>> 16;
  bytes[offset + 2] = value >>> 8;
  bytes[offset + 3] = value;
}
