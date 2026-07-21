import 'dart:math' as math;
import 'dart:typed_data';

import '../util/pcm.dart';

/// Stateful sine generator whose phase is preserved between tones.
final class ToneGenerator {
  ToneGenerator({required this.sampleRate, this.amplitude = 0.8})
      : assert(sampleRate > 0),
        assert(amplitude > 0 && amplitude <= 1);

  final int sampleRate;
  final double amplitude;
  double _phase = 0;

  double get phase => _phase;

  void reset() => _phase = 0;

  void write(Int16List target, int offset, int count, double frequency) {
    final double increment = 2 * math.pi * frequency / sampleRate;
    final double scale = int16Maximum * amplitude;
    for (int index = 0; index < count; index++) {
      target[offset + index] = (math.sin(_phase) * scale).round();
      _phase += increment;
      if (_phase >= 2 * math.pi) {
        _phase %= 2 * math.pi;
      }
    }
  }

  Int16List generate(double frequency, int sampleCount) {
    final Int16List result = Int16List(sampleCount);
    write(result, 0, sampleCount, frequency);
    return result;
  }
}
