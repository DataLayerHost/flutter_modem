import 'dart:typed_data';

import '../modem.dart';
import 'ready_signal.dart';

final class ReadySignalEncoderConfig {
  const ReadySignalEncoderConfig({
    this.leadingSilence = const Duration(milliseconds: 100),
    this.trailingSilence = const Duration(milliseconds: 200),
  });

  final Duration leadingSilence;
  final Duration trailingSilence;
}

/// Adds acoustic padding and encodes READY through a [FlutterModem].
final class ReadySignalEncoder {
  const ReadySignalEncoder({
    required this.modem,
    this.config = const ReadySignalEncoderConfig(),
  });

  final FlutterModem modem;
  final ReadySignalEncoderConfig config;

  Int16List encode(ReadySignal ready) {
    final int leading = _durationSamples(config.leadingSilence);
    final int trailing = _durationSamples(config.trailingSilence);
    final Int16List frame = modem.encode(ready.encodeFrame());
    final Int16List result = Int16List(leading + frame.length + trailing);
    result.setRange(leading, leading + frame.length, frame);
    return result;
  }

  int _durationSamples(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(
          duration, 'duration', 'Silence cannot be negative.');
    }
    return duration.inMicroseconds *
        modem.modulation.sampleRate ~/
        Duration.microsecondsPerSecond;
  }
}

final class ReadyRepeatConfig {
  const ReadyRepeatConfig({
    this.repeatInterval = const Duration(milliseconds: 300),
    this.maximumRepeats = 20,
    this.incrementSequenceNumber = true,
    this.maximumTotalDuration = const Duration(seconds: 30),
  });

  final Duration repeatInterval;
  final int maximumRepeats;
  final bool incrementSequenceNumber;
  final Duration maximumTotalDuration;
}

/// Lazily produces READY frame blocks alternating with inter-repeat silence.
final class RepeatingReadySignalEncoder {
  RepeatingReadySignalEncoder({
    required this.modem,
    required this.ready,
    Duration repeatInterval = const Duration(milliseconds: 300),
    int maximumRepeats = 20,
    bool incrementSequenceNumber = true,
    Duration maximumTotalDuration = const Duration(seconds: 30),
    this.encoderConfig = const ReadySignalEncoderConfig(),
  }) : config = ReadyRepeatConfig(
          repeatInterval: repeatInterval,
          maximumRepeats: maximumRepeats,
          incrementSequenceNumber: incrementSequenceNumber,
          maximumTotalDuration: maximumTotalDuration,
        ) {
    _validate();
  }

  RepeatingReadySignalEncoder.configured({
    required this.modem,
    required this.ready,
    required this.config,
    this.encoderConfig = const ReadySignalEncoderConfig(),
  }) {
    _validate();
  }

  final FlutterModem modem;
  final ReadySignal ready;
  final ReadyRepeatConfig config;
  final ReadySignalEncoderConfig encoderConfig;

  /// Yields one encoded frame, then one silence block between adjacent frames.
  Iterable<Int16List> chunks() sync* {
    final ReadySignalEncoder encoder = ReadySignalEncoder(
      modem: modem,
      config: encoderConfig,
    );
    final int silenceSamples = _durationSamples(config.repeatInterval);
    for (int index = 0; index < config.maximumRepeats; index++) {
      final int sequence = config.incrementSequenceNumber
          ? (ready.sequenceNumber + index) & 0xffff
          : ready.sequenceNumber;
      yield encoder.encode(ready.copyWith(sequenceNumber: sequence));
      if (index + 1 < config.maximumRepeats) {
        yield Int16List(silenceSamples);
      }
    }
  }

  Int16List encodeAll() {
    final int maximumSamples = _durationSamples(config.maximumTotalDuration);
    final List<Int16List> generated = <Int16List>[];
    int total = 0;
    for (final Int16List chunk in chunks()) {
      total += chunk.length;
      if (total > maximumSamples) {
        throw StateError('Repeated READY audio exceeds maximumTotalDuration.');
      }
      generated.add(chunk);
    }
    final Int16List result = Int16List(total);
    int offset = 0;
    for (final Int16List chunk in generated) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  int _durationSamples(Duration duration) =>
      duration.inMicroseconds *
      modem.modulation.sampleRate ~/
      Duration.microsecondsPerSecond;

  void _validate() {
    if (config.maximumRepeats <= 0) {
      throw RangeError.value(
        config.maximumRepeats,
        'maximumRepeats',
        'Must be positive.',
      );
    }
    if (config.repeatInterval.isNegative) {
      throw ArgumentError.value(
        config.repeatInterval,
        'repeatInterval',
        'Cannot be negative.',
      );
    }
    if (config.maximumTotalDuration <= Duration.zero) {
      throw ArgumentError.value(
        config.maximumTotalDuration,
        'maximumTotalDuration',
        'Must be positive.',
      );
    }
    ready.encodeFrame();
  }
}
