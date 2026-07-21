import 'dart:math' as math;

/// Single-frequency detector using the Goertzel recurrence.
final class Goertzel {
  Goertzel({required this.sampleRate, required this.frequency})
      : assert(sampleRate > 0),
        assert(frequency > 0),
        _coefficient = 2 * math.cos(2 * math.pi * frequency / sampleRate);

  final int sampleRate;
  final double frequency;
  final double _coefficient;

  /// Returns the unnormalized energy at [frequency].
  double power(Iterable<num> samples) {
    double previous = 0;
    double previous2 = 0;
    for (final num sample in samples) {
      final double current =
          sample.toDouble() + _coefficient * previous - previous2;
      previous2 = previous;
      previous = current;
    }
    return previous2 * previous2 +
        previous * previous -
        _coefficient * previous * previous2;
  }
}
