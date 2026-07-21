import 'dart:typed_data';

import '../framing/byte_codec.dart';
import '../framing/crc16.dart';
import 'modem_control_type.dart';

/// Error raised while validating a binary modem control frame.
final class ModemControlFrameException implements FormatException {
  const ModemControlFrameException(this.message, {this.source, this.offset});

  @override
  final String message;
  @override
  final dynamic source;
  @override
  final int? offset;

  @override
  String toString() => 'ModemControlFrameException: $message';
}

/// Generic immutable 16-byte control frame.
final class ModemControlFrame {
  const ModemControlFrame({
    required this.type,
    required this.sessionId,
    required this.flags,
    required this.guardDelayMilliseconds,
    required this.receiverTimeoutSeconds,
    required this.sequenceNumber,
    this.version = currentVersion,
  });

  static const int length = 16;
  static const int currentVersion = 1;
  static const int magic0 = 0x44;
  static const int magic1 = 0x4d;

  final int version;
  final ModemControlType type;
  final int sessionId;
  final int flags;
  final int guardDelayMilliseconds;
  final int receiverTimeoutSeconds;
  final int sequenceNumber;

  Uint8List encode() {
    _checkRange(sessionId, 0xffffffff, 'sessionId');
    _checkRange(flags, 0xff, 'flags');
    _checkRange(guardDelayMilliseconds, 0xffff, 'guardDelayMilliseconds');
    _checkRange(receiverTimeoutSeconds, 0xff, 'receiverTimeoutSeconds');
    _checkRange(sequenceNumber, 0xffff, 'sequenceNumber');
    if (version != currentVersion) {
      throw RangeError.value(version, 'version', 'Unsupported version.');
    }

    final Uint8List bytes = Uint8List(length);
    bytes[0] = magic0;
    bytes[1] = magic1;
    bytes[2] = version;
    bytes[3] = type.wireValue;
    ByteCodec.writeUint32(bytes, 4, sessionId);
    bytes[8] = flags;
    ByteCodec.writeUint16(bytes, 9, guardDelayMilliseconds);
    bytes[11] = receiverTimeoutSeconds;
    ByteCodec.writeUint16(bytes, 12, sequenceNumber);
    ByteCodec.writeUint16(bytes, 14, Crc16CcittFalse.compute(bytes.take(14)));
    return bytes;
  }

  static ModemControlFrame decode(Uint8List input) {
    final Uint8List bytes = Uint8List.fromList(input);
    if (bytes.length != length) {
      throw ModemControlFrameException(
        'Control frame must contain exactly $length bytes.',
        source: input,
      );
    }
    if (bytes[0] != magic0 || bytes[1] != magic1) {
      throw ModemControlFrameException('Invalid control-frame magic.',
          source: input);
    }
    if (bytes[2] != currentVersion) {
      throw ModemControlFrameException(
        'Unsupported control protocol version: ${bytes[2]}.',
        source: input,
      );
    }
    final ModemControlType? type = ModemControlType.fromWireValue(bytes[3]);
    if (type == null) {
      throw ModemControlFrameException(
        'Unknown control type: ${bytes[3]}.',
        source: input,
      );
    }
    final int expectedCrc = ByteCodec.readUint16(bytes, 14);
    final int actualCrc = Crc16CcittFalse.compute(bytes.take(14));
    if (expectedCrc != actualCrc) {
      throw ModemControlFrameException('Control-frame CRC-16 failed.',
          source: input);
    }
    return ModemControlFrame(
      version: bytes[2],
      type: type,
      sessionId: ByteCodec.readUint32(bytes, 4),
      flags: bytes[8],
      guardDelayMilliseconds: ByteCodec.readUint16(bytes, 9),
      receiverTimeoutSeconds: bytes[11],
      sequenceNumber: ByteCodec.readUint16(bytes, 12),
    );
  }

  static void _checkRange(int value, int maximum, String name) {
    if (value < 0 || value > maximum) {
      throw RangeError.range(value, 0, maximum, name);
    }
  }
}
