import 'dart:typed_data';

import 'modem_control_frame.dart';
import 'modem_control_type.dart';

final class ReadySignalDecodeException implements FormatException {
  const ReadySignalDecodeException(this.message, {this.source, this.offset});

  @override
  final String message;
  @override
  final dynamic source;
  @override
  final int? offset;

  @override
  String toString() => 'ReadySignalDecodeException: $message';
}

/// Immutable READY control message.
final class ReadySignal {
  const ReadySignal({
    required this.sessionId,
    this.guardDelay = const Duration(milliseconds: 500),
    this.receiverTimeout = const Duration(seconds: 10),
    this.sequenceNumber = 0,
    this.flags = 0,
  });

  /// Requests a future acknowledgement. The READY layer only transports it.
  static const int requestAcknowledgementFlag = 0x01;
  static const int supportedFlagsMask = requestAcknowledgementFlag;

  final int sessionId;
  final Duration guardDelay;
  final Duration receiverTimeout;
  final int sequenceNumber;
  final int flags;

  Uint8List encodeFrame() {
    _validate();
    return ModemControlFrame(
      type: ModemControlType.ready,
      sessionId: sessionId,
      flags: flags,
      guardDelayMilliseconds: guardDelay.inMilliseconds,
      receiverTimeoutSeconds: receiverTimeout.inSeconds,
      sequenceNumber: sequenceNumber,
    ).encode();
  }

  static ReadySignal decodeFrame(Uint8List bytes) {
    try {
      final ModemControlFrame frame = ModemControlFrame.decode(bytes);
      if (frame.type != ModemControlType.ready) {
        throw ReadySignalDecodeException(
          'Expected READY, received ${frame.type.name}.',
          source: bytes,
        );
      }
      final ReadySignal signal = ReadySignal(
        sessionId: frame.sessionId,
        guardDelay: Duration(milliseconds: frame.guardDelayMilliseconds),
        receiverTimeout: Duration(seconds: frame.receiverTimeoutSeconds),
        sequenceNumber: frame.sequenceNumber,
        flags: frame.flags,
      );
      signal._validateForDecode(bytes);
      return signal;
    } on ReadySignalDecodeException {
      rethrow;
    } on ModemControlFrameException catch (error) {
      throw ReadySignalDecodeException(error.message, source: bytes);
    }
  }

  ReadySignal copyWith({
    int? sessionId,
    Duration? guardDelay,
    Duration? receiverTimeout,
    int? sequenceNumber,
    int? flags,
  }) =>
      ReadySignal(
        sessionId: sessionId ?? this.sessionId,
        guardDelay: guardDelay ?? this.guardDelay,
        receiverTimeout: receiverTimeout ?? this.receiverTimeout,
        sequenceNumber: sequenceNumber ?? this.sequenceNumber,
        flags: flags ?? this.flags,
      );

  void _validate() {
    _range(sessionId, 0xffffffff, 'sessionId');
    _range(sequenceNumber, 0xffff, 'sequenceNumber');
    _range(flags, 0xff, 'flags');
    if ((flags & ~supportedFlagsMask) != 0) {
      throw ArgumentError.value(
          flags, 'flags', 'Contains unsupported required flags.');
    }
    if (guardDelay.isNegative ||
        guardDelay.inMicroseconds % Duration.microsecondsPerMillisecond != 0) {
      throw ArgumentError.value(
        guardDelay,
        'guardDelay',
        'Must be a non-negative whole number of milliseconds.',
      );
    }
    _range(guardDelay.inMilliseconds, 0xffff, 'guardDelay');
    if (receiverTimeout.isNegative ||
        receiverTimeout.inMicroseconds % Duration.microsecondsPerSecond != 0) {
      throw ArgumentError.value(
        receiverTimeout,
        'receiverTimeout',
        'Must be a non-negative whole number of seconds.',
      );
    }
    _range(receiverTimeout.inSeconds, 0xff, 'receiverTimeout');
  }

  void _validateForDecode(Uint8List source) {
    try {
      _validate();
    } on Object catch (error) {
      throw ReadySignalDecodeException(error.toString(), source: source);
    }
  }

  static void _range(int value, int maximum, String name) {
    if (value < 0 || value > maximum) {
      throw RangeError.range(value, 0, maximum, name);
    }
  }
}
