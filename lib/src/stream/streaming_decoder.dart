import 'dart:async';

import '../config.dart';
import '../decoder/bfsk_decoder.dart';
import '../protocol/frame.dart';

/// Push-based decoder that emits CRC-validated frames as a broadcast stream.
final class StreamingBfskDecoder implements ModemFrameDecoder {
  StreamingBfskDecoder({Bfsk config = const Bfsk()})
      : _decoder = BfskDecoder(config: config);

  final BfskDecoder _decoder;
  final StreamController<ModemFrame> _controller =
      StreamController<ModemFrame>.broadcast(sync: true);
  bool _closed = false;

  Stream<ModemFrame> get frames => _controller.stream;

  @override
  List<ModemFrame> feed(Iterable<int> pcm) {
    if (_closed) {
      throw StateError('The streaming decoder is closed.');
    }
    final List<ModemFrame> decoded = _decoder.feed(pcm);
    for (final ModemFrame frame in decoded) {
      _controller.add(frame);
    }
    return decoded;
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
