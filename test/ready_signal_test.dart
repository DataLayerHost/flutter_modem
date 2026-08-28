import 'dart:typed_data';

import 'package:flutter_modem/flutter_modem.dart';
import 'package:test/test.dart';

void main() {
  group('READY frame', () {
    test('round-trips all fields in exactly 16 bytes', () {
      const ReadySignal original = ReadySignal(
        sessionId: 0x12345678,
        guardDelay: Duration(milliseconds: 65535),
        receiverTimeout: Duration(seconds: 255),
        sequenceNumber: 65535,
        flags: ReadySignal.requestAcknowledgementFlag,
      );
      final Uint8List bytes = original.encodeFrame();
      final ReadySignal decoded = ReadySignal.decodeFrame(bytes);
      expect(bytes, hasLength(ModemControlFrame.length));
      expect(decoded.sessionId, 0x12345678);
      expect(decoded.guardDelay, const Duration(milliseconds: 65535));
      expect(decoded.receiverTimeout, const Duration(seconds: 255));
      expect(decoded.sequenceNumber, 65535);
      expect(decoded.flags, ReadySignal.requestAcknowledgementFlag);
    });

    test('supports minimum values', () {
      final ReadySignal decoded = ReadySignal.decodeFrame(
        const ReadySignal(
          sessionId: 0,
          guardDelay: Duration.zero,
          receiverTimeout: Duration.zero,
          sequenceNumber: 0,
        ).encodeFrame(),
      );
      expect(decoded.sessionId, 0);
      expect(decoded.guardDelay, Duration.zero);
      expect(decoded.receiverTimeout, Duration.zero);
      expect(decoded.sequenceNumber, 0);
    });

    test('preserves the maximum unsigned session ID', () {
      final ReadySignal decoded = ReadySignal.decodeFrame(
        const ReadySignal(sessionId: 0xffffffff).encodeFrame(),
      );
      expect(decoded.sessionId, 0xffffffff);
    });

    test('uses stable explicit control type values', () {
      expect(ModemControlType.ready.wireValue, 1);
      expect(ModemControlType.acknowledgement.wireValue, 2);
      expect(ModemControlType.negativeAcknowledgement.wireValue, 3);
      expect(ModemControlType.accepted.wireValue, 4);
      expect(ModemControlType.rejected.wireValue, 5);
      expect(ModemControlType.error.wireValue, 6);
    });

    test('CRC-16 matches the CCITT-FALSE check value', () {
      expect(Crc16CcittFalse.compute('123456789'.codeUnits), 0x29b1);
    });

    test('rejects invalid magic, version, CRC, truncation, and trailing bytes',
        () {
      final Uint8List valid = const ReadySignal(sessionId: 7).encodeFrame();

      Uint8List mutate(int index, int value, {bool repairCrc = false}) {
        final Uint8List bytes = Uint8List.fromList(valid)..[index] = value;
        if (repairCrc) {
          ByteCodec.writeUint16(
              bytes, 14, Crc16CcittFalse.compute(bytes.take(14)));
        }
        return bytes;
      }

      expect(
        () => ReadySignal.decodeFrame(mutate(0, 0, repairCrc: true)),
        throwsA(isA<ReadySignalDecodeException>()),
      );
      expect(
        () => ReadySignal.decodeFrame(mutate(2, 2, repairCrc: true)),
        throwsA(isA<ReadySignalDecodeException>()),
      );
      expect(
        () => ReadySignal.decodeFrame(mutate(4, valid[4] ^ 1)),
        throwsA(isA<ReadySignalDecodeException>()),
      );
      expect(
        () => ReadySignal.decodeFrame(Uint8List.fromList(valid.sublist(0, 15))),
        throwsA(isA<ReadySignalDecodeException>()),
      );
      expect(
        () => ReadySignal.decodeFrame(Uint8List.fromList(<int>[...valid, 0])),
        throwsA(isA<ReadySignalDecodeException>()),
      );
    });

    test('rejects the wrong control type and unsupported flags', () {
      final Uint8List wrongType = const ModemControlFrame(
        type: ModemControlType.acknowledgement,
        sessionId: 1,
        flags: 0,
        guardDelayMilliseconds: 0,
        receiverTimeoutSeconds: 0,
        sequenceNumber: 0,
      ).encode();
      final Uint8List badFlags = const ModemControlFrame(
        type: ModemControlType.ready,
        sessionId: 1,
        flags: 0x80,
        guardDelayMilliseconds: 0,
        receiverTimeoutSeconds: 0,
        sequenceNumber: 0,
      ).encode();
      expect(
        () => ReadySignal.decodeFrame(wrongType),
        throwsA(isA<ReadySignalDecodeException>()),
      );
      expect(
        () => ReadySignal.decodeFrame(badFlags),
        throwsA(isA<ReadySignalDecodeException>()),
      );
    });

    test('validates numeric and duration ranges', () {
      expect(
        () => const ReadySignal(sessionId: -1).encodeFrame(),
        throwsRangeError,
      );
      expect(
        () => const ReadySignal(sessionId: 0x100000000).encodeFrame(),
        throwsRangeError,
      );
      expect(
        () => const ReadySignal(sessionId: 1, sequenceNumber: 65536)
            .encodeFrame(),
        throwsRangeError,
      );
      expect(
        () => const ReadySignal(
          sessionId: 1,
          guardDelay: Duration(milliseconds: 65536),
        ).encodeFrame(),
        throwsRangeError,
      );
      expect(
        () => const ReadySignal(
          sessionId: 1,
          receiverTimeout: Duration(seconds: 256),
        ).encodeFrame(),
        throwsRangeError,
      );
    });

    test('does not retain mutable input or output arrays', () {
      final Uint8List bytes = const ReadySignal(sessionId: 99).encodeFrame();
      final ReadySignal decoded = ReadySignal.decodeFrame(bytes);
      bytes.fillRange(0, bytes.length, 0);
      expect(ReadySignal.decodeFrame(decoded.encodeFrame()).sessionId, 99);
      final Uint8List first = decoded.encodeFrame();
      final Uint8List second = decoded.encodeFrame();
      first[0] = 0;
      expect(second[0], ModemControlFrame.magic0);
    });
  });
}
