import 'dart:typed_data';

import 'package:flutter_modem/flutter_modem.dart';
import 'package:test/test.dart';

void main() {
  group('READY PCM encoder', () {
    final FlutterModem modem = FlutterModem();
    const ReadySignal ready = ReadySignal(sessionId: 0x12345678);

    test('modem loopback recovers the exact READY frame', () {
      const ReadySignalEncoderConfig config = ReadySignalEncoderConfig(
        leadingSilence: Duration.zero,
        trailingSilence: Duration.zero,
      );
      final Int16List pcm =
          ReadySignalEncoder(modem: modem, config: config).encode(
        ready,
      );
      final List<ModemFrame> frames = modem.createDecoder().feed(pcm);
      expect(frames, hasLength(1));
      expect(frames.single.payload, ready.encodeFrame());
    });

    test('adds exact leading and trailing silence', () {
      const ReadySignalEncoderConfig config = ReadySignalEncoderConfig(
        leadingSilence: Duration(milliseconds: 25),
        trailingSilence: Duration(milliseconds: 50),
      );
      final ReadySignalEncoder encoder = ReadySignalEncoder(
        modem: modem,
        config: config,
      );
      final Int16List first = encoder.encode(ready);
      final int leading = modem.modulation.sampleRate * 25 ~/ 1000;
      final int trailing = modem.modulation.sampleRate * 50 ~/ 1000;
      expect(first.length, greaterThan(leading + trailing));
      expect(first.take(leading), everyElement(0));
      expect(first.skip(first.length - trailing), everyElement(0));
    });
  });

  group('repeating READY encoder', () {
    final FlutterModem modem = FlutterModem();
    const ReadySignal ready = ReadySignal(sessionId: 55, sequenceNumber: 8);
    const ReadySignalEncoderConfig noPadding = ReadySignalEncoderConfig(
      leadingSilence: Duration.zero,
      trailingSilence: Duration.zero,
    );

    test('yields exact frames and inter-repeat silence lazily', () {
      final RepeatingReadySignalEncoder repeater = RepeatingReadySignalEncoder(
        modem: modem,
        ready: ready,
        repeatInterval: const Duration(milliseconds: 10),
        maximumRepeats: 3,
        encoderConfig: noPadding,
      );
      final Iterator<Int16List> iterator = repeater.chunks().iterator;
      expect(iterator.moveNext(), isTrue);
      final Int16List firstFrame = iterator.current;
      expect(firstFrame, isNotEmpty);
      expect(iterator.moveNext(), isTrue);
      expect(iterator.current.length, modem.modulation.sampleRate ~/ 100);
      expect(iterator.current, everyElement(0));
      expect(iterator.moveNext(), isTrue);
      expect(iterator.current, isNotEmpty);
      expect(repeater.chunks().length, 5);
    });

    test('increments sequence while preserving the session', () {
      final RepeatingReadySignalEncoder repeater = RepeatingReadySignalEncoder(
        modem: modem,
        ready: ready,
        repeatInterval: Duration.zero,
        maximumRepeats: 3,
        encoderConfig: noPadding,
      );
      final List<ReadySignal> signals = repeater
          .chunks()
          .where((Int16List chunk) => chunk.isNotEmpty)
          .map((Int16List chunk) {
        final ModemFrame frame = modem.createDecoder().feed(chunk).single;
        return ReadySignal.decodeFrame(frame.payload);
      }).toList();
      expect(signals.map((ReadySignal value) => value.sessionId),
          everyElement(55));
      expect(signals.map((ReadySignal value) => value.sequenceNumber),
          <int>[8, 9, 10]);
    });

    test('can keep sequence number constant', () {
      final RepeatingReadySignalEncoder repeater = RepeatingReadySignalEncoder(
        modem: modem,
        ready: ready,
        repeatInterval: Duration.zero,
        maximumRepeats: 2,
        incrementSequenceNumber: false,
        encoderConfig: noPadding,
      );
      final List<Int16List> frames =
          repeater.chunks().where((chunk) => chunk.isNotEmpty).toList();
      for (final Int16List pcm in frames) {
        final ModemFrame frame = modem.createDecoder().feed(pcm).single;
        expect(ReadySignal.decodeFrame(frame.payload).sequenceNumber, 8);
      }
    });

    test('encodeAll enforces maximum duration', () {
      final RepeatingReadySignalEncoder repeater = RepeatingReadySignalEncoder(
        modem: modem,
        ready: ready,
        maximumRepeats: 2,
        maximumTotalDuration: const Duration(milliseconds: 1),
        encoderConfig: noPadding,
      );
      expect(repeater.encodeAll, throwsStateError);
    });

    test('rejects non-positive repeat counts', () {
      expect(
        () => RepeatingReadySignalEncoder(
          modem: modem,
          ready: ready,
          maximumRepeats: 0,
        ),
        throwsRangeError,
      );
    });
  });
}
