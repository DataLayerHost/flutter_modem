import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_modem/dart_modem.dart';
import 'package:test/test.dart';

void main() {
  test('decodes a frame incrementally across arbitrary chunks', () {
    final Uint8List payload = Uint8List.fromList(utf8.encode('Hello'));
    final Int16List pcm = BfskEncoder().encode(payload);
    final BfskDecoder decoder = BfskDecoder();
    final List<ModemFrame> frames = <ModemFrame>[];
    for (int offset = 0; offset < pcm.length; offset += 37) {
      final int end = (offset + 37).clamp(0, pcm.length);
      frames.addAll(decoder.feed(pcm.sublist(offset, end)));
    }
    expect(frames, hasLength(1));
    expect(utf8.decode(frames.single.payload), 'Hello');
  });

  test('decodes back-to-back frames', () {
    final BfskEncoder encoder = BfskEncoder();
    final BfskDecoder decoder = BfskDecoder();
    final List<int> pcm = <int>[
      ...encoder.encode(<int>[1]),
      ...encoder.encode(<int>[2]),
    ];
    final List<ModemFrame> frames = decoder.feed(pcm);
    expect(frames.map((ModemFrame frame) => frame.payload.single), <int>[1, 2]);
  });

  test('rejects a frame with a corrupted CRC symbol', () {
    final BfskEncoder encoder = BfskEncoder();
    final Int16List pcm = encoder.encode(<int>[1, 2, 3]);
    const Bfsk config = Bfsk();
    final Uint8List packet = Packet(<int>[1, 2, 3]).encode();
    final int lastBit = packet.last & 1;
    final int sourceSymbol = lastBit == 1
        ? config.carrierBits + 1 // zero bit in alternating preamble
        : 0; // one bit in carrier
    final int destinationSymbol = pcm.length ~/ config.samplesPerBit - 1;
    pcm.setRange(
      destinationSymbol * config.samplesPerBit,
      (destinationSymbol + 1) * config.samplesPerBit,
      pcm,
      sourceSymbol * config.samplesPerBit,
    );
    expect(BfskDecoder().feed(pcm), isEmpty);
  });

  test('streaming API emits frames', () async {
    final StreamingBfskDecoder decoder = StreamingBfskDecoder();
    final Future<ModemFrame> first = decoder.frames.first;
    decoder.feed(BfskEncoder().encode(<int>[7, 8]));
    expect((await first).payload, <int>[7, 8]);
    await decoder.close();
  });

  test('near-ultrasonic preset round-trips incrementally', () {
    const Bfsk config = Bfsk.ultrasonic();
    final Int16List pcm = BfskEncoder(config: config).encode(<int>[9, 8, 7]);
    final BfskDecoder decoder = BfskDecoder(config: config);
    final List<ModemFrame> frames = <ModemFrame>[];
    for (int offset = 0; offset < pcm.length; offset += 997) {
      final int end = (offset + 997).clamp(0, pcm.length);
      frames.addAll(decoder.feed(pcm.sublist(offset, end)));
    }
    expect(frames, hasLength(1));
    expect(frames.single.payload, <int>[9, 8, 7]);
  });

  test('fast preset round-trips incrementally', () {
    const Bfsk config = Bfsk.fast();
    final Int16List pcm = BfskEncoder(config: config).encode(
      List<int>.generate(256, (int index) => index),
    );
    final BfskDecoder decoder = BfskDecoder(config: config);
    final List<ModemFrame> frames = <ModemFrame>[];
    for (int offset = 0; offset < pcm.length; offset += 613) {
      final int end = (offset + 613).clamp(0, pcm.length);
      frames.addAll(decoder.feed(pcm.sublist(offset, end)));
    }
    expect(frames, hasLength(1));
    expect(
      frames.single.payload,
      List<int>.generate(256, (int index) => index),
    );
  });

  test('poor-quality preset round-trips incrementally', () {
    const Bfsk config = Bfsk.poorQuality();
    final Int16List pcm = BfskEncoder(config: config).encode(<int>[4, 2]);
    final BfskDecoder decoder = BfskDecoder(config: config);
    final List<ModemFrame> frames = <ModemFrame>[];
    for (int offset = 0; offset < pcm.length; offset += 53) {
      final int end = (offset + 53).clamp(0, pcm.length);
      frames.addAll(decoder.feed(pcm.sublist(offset, end)));
    }
    expect(frames, hasLength(1));
    expect(frames.single.payload, <int>[4, 2]);
  });
}
