import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_modem/flutter_modem.dart';

Future<void> main() async {
  final Int16List pcm = BfskEncoder().encode(utf8.encode('Hello'));
  final StreamingBfskDecoder decoder = StreamingBfskDecoder();
  decoder.frames.listen((ModemFrame frame) {
    print(utf8.decode(frame.payload));
  });

  for (int offset = 0; offset < pcm.length; offset += 127) {
    final int end = (offset + 127).clamp(0, pcm.length);
    decoder.feed(pcm.sublist(offset, end));
  }
  await decoder.close();
}
