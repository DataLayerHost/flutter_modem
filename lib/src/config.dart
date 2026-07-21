/// Settings shared by the BFSK encoder and decoder.
final class Bfsk {
  const Bfsk({
    this.sampleRate = 48000,
    this.baudRate = 1200,
    this.zeroFrequency = 2100,
    this.oneFrequency = 1300,
    this.amplitude = 0.8,
    this.carrierBits = 24,
    this.preambleBits = 48,
    this.maximumPayloadLength = 1024 * 1024,
  })  : assert(sampleRate > 0),
        assert(baudRate > 0),
        assert(sampleRate % baudRate == 0),
        assert(zeroFrequency > 0),
        assert(oneFrequency > 0),
        assert(zeroFrequency < sampleRate / 2),
        assert(oneFrequency < sampleRate / 2),
        assert(zeroFrequency != oneFrequency),
        assert(amplitude > 0 && amplitude <= 1),
        assert(carrierBits >= 0),
        assert(preambleBits >= 8),
        assert(maximumPayloadLength >= 0);

  /// Slow profile for noisy, filtered, or otherwise poor-quality links.
  const Bfsk.poorQuality({
    int sampleRate = 8000,
    int baudRate = 100,
    double zeroFrequency = 1200,
    double oneFrequency = 2200,
    double amplitude = 0.8,
    int carrierBits = 16,
    int preambleBits = 32,
    int maximumPayloadLength = 1024 * 1024,
  }) : this(
          sampleRate: sampleRate,
          baudRate: baudRate,
          zeroFrequency: zeroFrequency,
          oneFrequency: oneFrequency,
          amplitude: amplitude,
          carrierBits: carrierBits,
          preambleBits: preambleBits,
          maximumPayloadLength: maximumPayloadLength,
        );

  /// Alias for [Bfsk.poorQuality].
  const Bfsk.robust({
    int sampleRate = 8000,
    int baudRate = 100,
    double zeroFrequency = 1200,
    double oneFrequency = 2200,
    double amplitude = 0.8,
    int carrierBits = 16,
    int preambleBits = 32,
    int maximumPayloadLength = 1024 * 1024,
  }) : this.poorQuality(
          sampleRate: sampleRate,
          baudRate: baudRate,
          zeroFrequency: zeroFrequency,
          oneFrequency: oneFrequency,
          amplitude: amplitude,
          carrierBits: carrierBits,
          preambleBits: preambleBits,
          maximumPayloadLength: maximumPayloadLength,
        );

  /// Near-ultrasonic preset for short-range communication over capable audio
  /// hardware.
  ///
  /// The 18.5/19.5 kHz tones require a 48 kHz PCM path. Actual speaker and
  /// microphone response varies considerably at these frequencies.
  const Bfsk.ultrasonic({
    int sampleRate = 48000,
    int baudRate = 100,
    double zeroFrequency = 18500,
    double oneFrequency = 19500,
    double amplitude = 0.8,
    int carrierBits = 16,
    int preambleBits = 32,
    int maximumPayloadLength = 1024 * 1024,
  }) : this(
          sampleRate: sampleRate,
          baudRate: baudRate,
          zeroFrequency: zeroFrequency,
          oneFrequency: oneFrequency,
          amplitude: amplitude,
          carrierBits: carrierBits,
          preambleBits: preambleBits,
          maximumPayloadLength: maximumPayloadLength,
        );

  /// High-speed audible preset with 40 samples per bit.
  ///
  /// The tones complete one and two full cycles per symbol respectively,
  /// improving Goertzel separation in the shorter 1200-baud window.
  const Bfsk.fast({
    int sampleRate = 48000,
    int baudRate = 1200,
    double zeroFrequency = 1200,
    double oneFrequency = 2400,
    double amplitude = 0.8,
    int carrierBits = 24,
    int preambleBits = 48,
    int maximumPayloadLength = 1024 * 1024,
  }) : this(
          sampleRate: sampleRate,
          baudRate: baudRate,
          zeroFrequency: zeroFrequency,
          oneFrequency: oneFrequency,
          amplitude: amplitude,
          carrierBits: carrierBits,
          preambleBits: preambleBits,
          maximumPayloadLength: maximumPayloadLength,
        );

  final int sampleRate;
  final int baudRate;
  final double zeroFrequency;
  final double oneFrequency;
  final double amplitude;
  final int carrierBits;
  final int preambleBits;
  final int maximumPayloadLength;

  int get samplesPerBit => sampleRate ~/ baudRate;
}
