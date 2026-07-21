import 'goertzel.dart';

/// Detects whether a PCM window contains either configured BFSK tone.
final class CarrierDetector {
  CarrierDetector({
    required int sampleRate,
    required double zeroFrequency,
    required double oneFrequency,
    this.minimumPower = 1e8,
  })  : zero = Goertzel(sampleRate: sampleRate, frequency: zeroFrequency),
        one = Goertzel(sampleRate: sampleRate, frequency: oneFrequency);

  final Goertzel zero;
  final Goertzel one;
  final double minimumPower;

  bool detect(Iterable<num> samples) =>
      zero.power(samples) >= minimumPower || one.power(samples) >= minimumPower;
}
