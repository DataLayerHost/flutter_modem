import 'dart:typed_data';

/// A bounds-checking big-endian binary reader.
final class ByteReader {
  ByteReader(this.data);

  final Uint8List data;
  int offset = 0;

  int get remaining => data.length - offset;

  void require(int count) {
    if (count < 0 || remaining < count) {
      throw const FormatException('Truncated binary data');
    }
  }

  int readUint8() {
    require(1);
    return data[offset++];
  }

  int readUint16() {
    require(2);
    final value = ByteData.sublistView(data).getUint16(offset, Endian.big);
    offset += 2;
    return value;
  }

  int readUint32() {
    require(4);
    final value = ByteData.sublistView(data).getUint32(offset, Endian.big);
    offset += 4;
    return value;
  }

  int readUint64() {
    require(8);
    final value = ByteData.sublistView(data).getUint64(offset, Endian.big);
    offset += 8;
    return value;
  }

  Uint8List readBytes(int count) {
    require(count);
    final value = Uint8List.fromList(data.sublist(offset, offset + count));
    offset += count;
    return value;
  }
}
