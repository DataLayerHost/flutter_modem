import 'dart:async';

import '../protocol/frame.dart';
import '../protocol/modem_protocol.dart';
import '../protocol/packet.dart';
import 'bfsk_decoder.dart';

/// Applies an application protocol decoder to frames recovered by a modem.
final class ProtocolModemDecoder implements ModemFrameDecoder {
  ProtocolModemDecoder({
    required ModemFrameDecoder modemDecoder,
    required ModemProtocolDecoder protocolDecoder,
  })  : _modemDecoder = modemDecoder,
        _protocolDecoder = protocolDecoder;

  final ModemFrameDecoder _modemDecoder;
  final ModemProtocolDecoder _protocolDecoder;

  @override
  List<ModemFrame> feed(Iterable<int> pcm) {
    final List<ModemFrame> decoded = <ModemFrame>[];
    for (final ModemFrame frame in _modemDecoder.feed(pcm)) {
      for (final payload in _protocolDecoder.decode(frame.payload)) {
        decoded.add(ModemFrame(Packet(payload)));
      }
    }
    return decoded;
  }

  @override
  void reset() {
    _modemDecoder.reset();
    _protocolDecoder.reset();
  }
}

/// Push-based protocol-aware modem decoder.
final class StreamingDartModemDecoder implements ModemFrameDecoder {
  StreamingDartModemDecoder(this._decoder);

  final ModemFrameDecoder _decoder;
  final StreamController<ModemFrame> _controller =
      StreamController<ModemFrame>.broadcast(sync: true);
  bool _closed = false;

  Stream<ModemFrame> get frames => _controller.stream;

  @override
  List<ModemFrame> feed(Iterable<int> pcm) {
    if (_closed) {
      throw StateError('The streaming decoder is closed.');
    }
    final List<ModemFrame> frames = _decoder.feed(pcm);
    for (final ModemFrame frame in frames) {
      _controller.add(frame);
    }
    return frames;
  }

  @override
  void reset() => _decoder.reset();

  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      await _controller.close();
    }
  }
}
