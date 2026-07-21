import 'dart:typed_data';

/// A small big-endian binary writer.
final class ByteWriter {
  ByteWriter(int length) : _data = Uint8List(length);

  final Uint8List _data;
  int _offset = 0;

  void writeUint8(int value) => _data[_offset++] = value;

  void writeUint16(int value) {
    ByteData.sublistView(_data).setUint16(_offset, value, Endian.big);
    _offset += 2;
  }

  void writeUint32(int value) {
    ByteData.sublistView(_data).setUint32(_offset, value, Endian.big);
    _offset += 4;
  }

  void writeUint64(int value) {
    ByteData.sublistView(_data).setUint64(_offset, value, Endian.big);
    _offset += 8;
  }

  void writeBytes(List<int> value) {
    _data.setRange(_offset, _offset + value.length, value);
    _offset += value.length;
  }

  /// Internal codec support for calculating a checksum before its field is written.
  List<int> prefixForChecksum(int length) => _data.sublist(0, length);

  Uint8List takeBytes() {
    if (_offset != _data.length) {
      throw StateError('Binary buffer is not completely written');
    }
    return Uint8List.fromList(_data);
  }
}
