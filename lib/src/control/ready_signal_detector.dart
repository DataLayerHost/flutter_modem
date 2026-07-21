import 'dart:collection';
import 'dart:typed_data';

import '../decoder/bfsk_decoder.dart';
import '../protocol/frame.dart';
import 'modem_control_frame.dart';
import 'ready_signal.dart';
import 'ready_signal_event.dart';

final class ReadySignalDetectorConfig {
  const ReadySignalDetectorConfig({
    this.emitDuplicates = false,
    this.maximumRememberedSessions = 16,
    this.acceptSequenceRegression = false,
  });

  final bool emitDuplicates;
  final int maximumRememberedSessions;
  final bool acceptSequenceRegression;
}

/// Converts incrementally decoded modem frames into validated READY events.
final class ReadySignalDetector {
  ReadySignalDetector({
    required this.modemDecoder,
    this.config = const ReadySignalDetectorConfig(),
  }) {
    if (config.maximumRememberedSessions <= 0) {
      throw RangeError.value(
        config.maximumRememberedSessions,
        'maximumRememberedSessions',
        'Must be positive.',
      );
    }
  }

  final ModemFrameDecoder modemDecoder;
  final ReadySignalDetectorConfig config;
  final LinkedHashMap<int, ReadySignal> _sessions =
      LinkedHashMap<int, ReadySignal>();
  int? _lastDetectedSessionId;

  int? get lastDetectedSessionId => _lastDetectedSessionId;

  Duration? get lastGuardDelay => _lastDetectedSessionId == null
      ? null
      : _sessions[_lastDetectedSessionId]?.guardDelay;

  Duration? get lastReceiverTimeout => _lastDetectedSessionId == null
      ? null
      : _sessions[_lastDetectedSessionId]?.receiverTimeout;

  List<ReadySignalEvent> add(Iterable<int> pcm) {
    final List<ReadySignalEvent> events = <ReadySignalEvent>[];
    for (final ModemFrame modemFrame in modemDecoder.feed(pcm)) {
      final Uint8List payload = modemFrame.payload;
      if (!_looksLikeControlFrame(payload)) {
        continue;
      }
      ReadySignal signal;
      try {
        signal = ReadySignal.decodeFrame(payload);
      } on ReadySignalDecodeException catch (error) {
        events.add(InvalidReadySignal(error));
        continue;
      }
      _handle(signal, events);
    }
    return events;
  }

  void reset() {
    modemDecoder.reset();
    _sessions.clear();
    _lastDetectedSessionId = null;
  }

  bool _looksLikeControlFrame(Uint8List payload) =>
      payload.length >= 2 &&
      payload[0] == ModemControlFrame.magic0 &&
      payload[1] == ModemControlFrame.magic1;

  void _handle(ReadySignal signal, List<ReadySignalEvent> events) {
    final ReadySignal? previous = _sessions[signal.sessionId];
    if (previous == null) {
      _remember(signal);
      _lastDetectedSessionId = signal.sessionId;
      events.add(ReadySignalDetected(signal: signal, isDuplicate: false));
      return;
    }
    if (!_sameSessionConfiguration(previous, signal)) {
      events.add(
        InvalidReadySignal(
          ReadySignalDecodeException(
            'Conflicting READY parameters for session ${signal.sessionId}.',
          ),
        ),
      );
      return;
    }

    final int delta =
        (signal.sequenceNumber - previous.sequenceNumber) & 0xffff;
    final bool sameSequence = delta == 0;
    final bool forwardSequence = delta > 0 && delta <= 0x7fff;
    if (!sameSequence && !forwardSequence && !config.acceptSequenceRegression) {
      return;
    }
    if (!sameSequence) {
      _sessions[signal.sessionId] = signal;
    }
    _lastDetectedSessionId = signal.sessionId;
    if (config.emitDuplicates) {
      events.add(ReadySignalDetected(signal: signal, isDuplicate: true));
    }
  }

  bool _sameSessionConfiguration(ReadySignal left, ReadySignal right) =>
      left.guardDelay == right.guardDelay &&
      left.receiverTimeout == right.receiverTimeout &&
      left.flags == right.flags;

  void _remember(ReadySignal signal) {
    if (_sessions.length == config.maximumRememberedSessions) {
      _sessions.remove(_sessions.keys.first);
    }
    _sessions[signal.sessionId] = signal;
  }
}
