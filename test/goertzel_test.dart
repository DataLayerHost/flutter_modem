import 'dart:math' as math;

import 'package:dart_modem/dart_modem.dart';
import 'package:test/test.dart';

void main() {
  test('selects the matching tone', () {
    const int sampleRate = 8000;
    final List<double> samples = List<double>.generate(
      80,
      (int index) => math.sin(2 * math.pi * 1200 * index / sampleRate),
    );
    final double matching =
        Goertzel(sampleRate: sampleRate, frequency: 1200).power(samples);
    final double other =
        Goertzel(sampleRate: sampleRate, frequency: 2200).power(samples);
    expect(matching, greaterThan(other * 100));
  });

  test('carrier detector distinguishes tone from silence', () {
    final CarrierDetector detector = CarrierDetector(
      sampleRate: 8000,
      zeroFrequency: 1200,
      oneFrequency: 2200,
    );
    final List<double> tone = List<double>.generate(
      80,
      (int index) => 1000 * math.sin(2 * math.pi * 2200 * index / 8000),
    );
    expect(detector.detect(tone), isTrue);
    expect(detector.detect(List<int>.filled(80, 0)), isFalse);
  });
}
