import 'dart:typed_data';

import '../config.dart';
import '../encoder/bfsk_encoder.dart';

/// Encodes each item in a byte stream as one independent modem frame.
final class StreamingBfskEncoder {
  StreamingBfskEncoder({Bfsk config = const Bfsk()})
      : _encoder = BfskEncoder(config: config);

  final BfskEncoder _encoder;

  Int16List encode(List<int> payload) => _encoder.encode(payload);

  Stream<Int16List> bind(Stream<List<int>> payloads) =>
      payloads.map(_encoder.encode);
}
