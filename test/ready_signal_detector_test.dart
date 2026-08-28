import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_modem/flutter_modem.dart';
import 'package:test/test.dart';

void main() {
  final FlutterModem modem = FlutterModem();
  Int16List encode(ReadySignal signal) =>
      ReadySignalEncoder(modem: modem).encode(signal);

  ReadySignalDetector detector({ReadySignalDetectorConfig? config}) =>
      ReadySignalDetector(
        modemDecoder: modem.createStreamingDecoder(),
        config: config ?? const ReadySignalDetectorConfig(),
      );

  group('READY detector', () {
    test('detects one READY and exposes timing metadata', () {
      final ReadySignalDetector value = detector();
      final List<ReadySignalEvent> events = value.add(
        encode(
          const ReadySignal(
            sessionId: 10,
            guardDelay: Duration(milliseconds: 750),
            receiverTimeout: Duration(seconds: 12),
          ),
        ),
      );
      final ReadySignalDetected event = events.single as ReadySignalDetected;
      expect(event.isDuplicate, isFalse);
      expect(event.signal.sessionId, 10);
      expect(value.lastDetectedSessionId, 10);
      expect(value.lastGuardDelay, const Duration(milliseconds: 750));
      expect(value.lastReceiverTimeout, const Duration(seconds: 12));
    });

    test('accepts one sample per call', () {
      final ReadySignalDetector value = detector();
      final Int16List pcm = encode(const ReadySignal(sessionId: 11));
      final List<ReadySignalEvent> events = <ReadySignalEvent>[];
      for (final int sample in pcm) {
        events.addAll(value.add(<int>[sample]));
      }
      expect(events, hasLength(1));
      expect((events.single as ReadySignalDetected).signal.sessionId, 11);
    });

    test('suppresses repeated sequences for one session by default', () {
      final RepeatingReadySignalEncoder repeater = RepeatingReadySignalEncoder(
        modem: modem,
        ready: const ReadySignal(sessionId: 12),
        maximumRepeats: 3,
      );
      final List<ReadySignalEvent> events =
          detector().add(repeater.encodeAll());
      expect(events, hasLength(1));
      expect((events.single as ReadySignalDetected).isDuplicate, isFalse);
    });

    test('emits exact and increasing-sequence duplicates when enabled', () {
      final ReadySignalDetector value = detector(
        config: const ReadySignalDetectorConfig(emitDuplicates: true),
      );
      final List<int> pcm = <int>[
        ...encode(const ReadySignal(sessionId: 13, sequenceNumber: 4)),
        ...encode(const ReadySignal(sessionId: 13, sequenceNumber: 4)),
        ...encode(const ReadySignal(sessionId: 13, sequenceNumber: 5)),
      ];
      final List<ReadySignalEvent> events = value.add(pcm);
      expect(events, hasLength(3));
      expect(
        events.map((event) => (event as ReadySignalDetected).isDuplicate),
        <bool>[false, true, true],
      );
    });

    test('rejects conflicting data for an existing session', () {
      final ReadySignalDetector value = detector();
      value.add(encode(const ReadySignal(sessionId: 14)));
      final List<ReadySignalEvent> events = value.add(
        encode(
          const ReadySignal(
            sessionId: 14,
            sequenceNumber: 1,
            guardDelay: Duration(milliseconds: 900),
          ),
        ),
      );
      expect(events.single, isA<InvalidReadySignal>());
    });

    test('ignores sequence regression unless configured', () {
      final ReadySignalDetector strict = detector(
        config: const ReadySignalDetectorConfig(emitDuplicates: true),
      );
      strict.add(encode(const ReadySignal(sessionId: 15, sequenceNumber: 10)));
      expect(
        strict.add(encode(const ReadySignal(sessionId: 15, sequenceNumber: 9))),
        isEmpty,
      );

      final ReadySignalDetector permissive = detector(
        config: const ReadySignalDetectorConfig(
          emitDuplicates: true,
          acceptSequenceRegression: true,
        ),
      );
      permissive
          .add(encode(const ReadySignal(sessionId: 15, sequenceNumber: 10)));
      expect(
        permissive
            .add(encode(const ReadySignal(sessionId: 15, sequenceNumber: 9))),
        hasLength(1),
      );
    });

    test('ignores unrelated modem payloads', () {
      final ReadySignalDetector value = detector();
      expect(value.add(modem.encode(<int>[1, 2, 3])), isEmpty);
    });

    test('emits an invalid event for a corrupt inner CRC', () {
      final Uint8List corrupt = const ReadySignal(sessionId: 16).encodeFrame();
      corrupt[5] ^= 1;
      final List<ReadySignalEvent> events =
          detector().add(modem.encode(corrupt));
      expect(events.single, isA<InvalidReadySignal>());
    });

    test('reset clears duplicate state and decoder state', () {
      final ReadySignalDetector value = detector();
      final Int16List pcm = encode(const ReadySignal(sessionId: 17));
      expect(value.add(pcm), hasLength(1));
      value.reset();
      expect(value.lastDetectedSessionId, isNull);
      expect(value.add(pcm), hasLength(1));
    });

    test('bounds remembered sessions and evicts the oldest', () {
      final ReadySignalDetector value = detector(
        config: const ReadySignalDetectorConfig(maximumRememberedSessions: 2),
      );
      value.add(encode(const ReadySignal(sessionId: 1)));
      value.add(encode(const ReadySignal(sessionId: 2)));
      value.add(encode(const ReadySignal(sessionId: 3)));
      final List<ReadySignalEvent> events = value.add(
        encode(const ReadySignal(sessionId: 1)),
      );
      expect(events, hasLength(1));
      expect((events.single as ReadySignalDetected).isDuplicate, isFalse);
    });
  });

  group('READY waiter', () {
    test('returns recommended guard delay and supports reset', () {
      final ReadySignalWaiter waiter = ReadySignalWaiter(detector: detector());
      expect(waiter.add(const <int>[]), isA<ReadyNotDetected>());
      final ReadyWaitResult result = waiter.add(
        encode(
          const ReadySignal(
            sessionId: 18,
            guardDelay: Duration(milliseconds: 625),
          ),
        ),
      );
      expect(result, isA<ReadyReceived>());
      expect(
        (result as ReadyReceived).recommendedTransmitDelay,
        const Duration(milliseconds: 625),
      );
      waiter.reset();
    });
  });

  group('READY deterministic impairments', () {
    const ReadySignal signal = ReadySignal(sessionId: 0xfeedbeef);

    void expectDetected(Iterable<int> pcm, {Iterable<int>? chunks}) {
      final ReadySignalDetector value = detector();
      final List<int> samples = pcm.toList(growable: false);
      final List<ReadySignalEvent> events = <ReadySignalEvent>[];
      if (chunks == null) {
        events.addAll(value.add(samples));
      } else {
        int offset = 0;
        for (final int size in chunks) {
          if (offset == samples.length) {
            break;
          }
          final int end = math.min(offset + size, samples.length);
          events.addAll(value.add(samples.sublist(offset, end)));
          offset = end;
        }
        if (offset < samples.length) {
          events.addAll(value.add(samples.sublist(offset)));
        }
      }
      expect(events.whereType<ReadySignalDetected>(), hasLength(1));
    }

    test('survives leading/trailing silence and arbitrary boundaries', () {
      final Int16List pcm = encode(signal);
      final math.Random random = math.Random(42);
      expectDetected(
        <int>[
          ...List<int>.filled(4800, 0),
          ...pcm,
          ...List<int>.filled(9600, 0)
        ],
        chunks: List<int>.generate(200, (_) => random.nextInt(311) + 1),
      );
    });

    test('survives amplitude reduced to 25 percent', () {
      expectDetected(
          encode(signal).map((int sample) => (sample * 0.25).round()));
    });

    test('survives moderate deterministic white noise', () {
      final math.Random random = math.Random(1234);
      expectDetected(
        encode(signal).map(
          (int sample) =>
              (sample + random.nextInt(2001) - 1000).clamp(-32768, 32767),
        ),
      );
    });

    test('survives symmetric PCM clipping', () {
      expectDetected(
        encode(signal).map((int sample) => (sample * 2).clamp(-12000, 12000)),
      );
    });

    test('survives a G.711 mu-law encode/decode round trip', () {
      expectDetected(
        encode(signal).map((int sample) => _muLawDecode(_muLawEncode(sample))),
      );
    });
  });
}

int _muLawEncode(int input) {
  int sample = input.clamp(-32635, 32635);
  final int sign = sample < 0 ? 0x80 : 0;
  if (sample < 0) {
    sample = -sample;
  }
  sample += 0x84;
  int exponent = 7;
  for (int mask = 0x4000; exponent > 0 && (sample & mask) == 0; mask >>= 1) {
    exponent--;
  }
  final int mantissa = (sample >> (exponent + 3)) & 0x0f;
  return (~(sign | (exponent << 4) | mantissa)) & 0xff;
}

int _muLawDecode(int input) {
  final int value = (~input) & 0xff;
  final int sign = value & 0x80;
  final int exponent = (value >> 4) & 0x07;
  final int mantissa = value & 0x0f;
  final int magnitude = (((mantissa << 3) + 0x84) << exponent) - 0x84;
  return sign == 0 ? magnitude : -magnitude;
}
