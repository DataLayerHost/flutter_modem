import 'dart:typed_data';

import '../envelope/envelope_exception.dart';
import '../packet/packet_codec.dart';
import '../packet/packet_exception.dart';
import '../packet/voice_tx_packet.dart';
import '../util/byte_reader.dart';

typedef VoiceTxStreamErrorCallback = void Function(VoiceTxProtocolError error);

/// Recovering parser for arbitrarily chunked packet bytes.
final class VoiceTxStreamingPacketDecoder {
  VoiceTxStreamingPacketDecoder(
      {this.maximumPacketSize = 512,
      this.maximumBufferSize = 4096,
      this.onError}) {
    if (maximumPacketSize < PacketCodec.overhead ||
        maximumBufferSize < maximumPacketSize) {
      throw ArgumentError('Invalid streaming limits');
    }
  }
  final int maximumPacketSize;
  final int maximumBufferSize;
  final VoiceTxStreamErrorCallback? onError;
  Uint8List _buffer = Uint8List(0);
  bool _closed = false;

  List<VoiceTxPacket> add(Uint8List chunk) {
    if (_closed) throw StateError('Decoder is closed');
    if (chunk.isNotEmpty) {
      _buffer = Uint8List.fromList(<int>[..._buffer, ...chunk]);
    }
    final packets = <VoiceTxPacket>[];
    while (true) {
      final magic = _findMagic(_buffer);
      if (magic < 0) {
        if (_buffer.isNotEmpty && _buffer.last == 0x56) {
          _buffer = Uint8List.fromList(<int>[0x56]);
        } else {
          _buffer = Uint8List(0);
        }
        break;
      }
      if (magic > 0) {
        _report(VoiceTxProtocolError.invalidMagic);
        _buffer = Uint8List.fromList(_buffer.sublist(magic));
      }
      if (_buffer.length < PacketCodec.headerLength) break;
      final payloadLength =
          ByteReader(Uint8List.fromList(_buffer.sublist(17, 19))).readUint16();
      final total = PacketCodec.overhead + payloadLength;
      if (total > maximumPacketSize) {
        _report(VoiceTxProtocolError.payloadTooLarge);
        _discardOne();
        continue;
      }
      if (_buffer.length < total) break;
      final candidate = Uint8List.fromList(_buffer.sublist(0, total));
      try {
        packets.add(VoiceTxPacket.decode(candidate,
            maximumPayloadSize: maximumPacketSize - PacketCodec.overhead));
        _buffer = Uint8List.fromList(_buffer.sublist(total));
      } on VoiceTxPacketException catch (error) {
        _report(error.error);
        _discardOne();
      }
    }
    if (_buffer.length > maximumBufferSize) {
      _report(VoiceTxProtocolError.payloadTooLarge);
      _buffer = Uint8List.fromList(
          _buffer.sublist(_buffer.length - maximumBufferSize));
    }
    return packets;
  }

  void _discardOne() => _buffer = _buffer.length <= 1
      ? Uint8List(0)
      : Uint8List.fromList(_buffer.sublist(1));
  void _report(VoiceTxProtocolError error) => onError?.call(error);
  void reset() {
    _buffer = Uint8List(0);
    _closed = false;
  }

  void close() {
    if (_buffer.isNotEmpty) {
      _report(VoiceTxProtocolError.incompleteTransmission);
    }
    _buffer = Uint8List(0);
    _closed = true;
  }
}

int _findMagic(Uint8List bytes) {
  for (var index = 0; index + 1 < bytes.length; index++) {
    if (bytes[index] == 0x56 && bytes[index + 1] == 0x54) return index;
  }
  return -1;
}
