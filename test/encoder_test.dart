import 'dart:typed_data';

import 'package:flutter_modem/flutter_modem.dart';
import 'package:test/test.dart';

void main() {
  test('generates signed Int16 PCM at the configured symbol rate', () {
    const Bfsk config = Bfsk(sampleRate: 8000, baudRate: 100);
    final Int16List pcm = BfskEncoder(config: config).encode(<int>[42]);
    final int packetBits = (Packet.headerLength + 1 + Packet.crcLength) * 8;
    final int expectedBits = config.carrierBits +
        config.preambleBits +
        Preamble.syncWordBits +
        packetBits;
    expect(pcm.length, expectedBits * config.samplesPerBit);
    expect(pcm, contains(isNot(0)));
  });

  test('tone generator preserves phase between writes', () {
    final ToneGenerator split = ToneGenerator(sampleRate: 8000);
    final ToneGenerator whole = ToneGenerator(sampleRate: 8000);
    final Int16List splitPcm = Int16List(80);
    split.write(splitPcm, 0, 31, 1200);
    split.write(splitPcm, 31, 49, 1200);
    expect(splitPcm, whole.generate(1200, 80));
  });

  test('ultrasonic preset uses a 48 kHz near-ultrasonic channel', () {
    const Bfsk config = Bfsk.ultrasonic();
    expect(config.sampleRate, 48000);
    expect(config.zeroFrequency, 18500);
    expect(config.oneFrequency, 19500);
    expect(config.samplesPerBit, 480);
  });

  test('fast preset provides a 1200-baud symbol-aligned channel', () {
    const Bfsk config = Bfsk.fast();
    expect(config.sampleRate, 48000);
    expect(config.baudRate, 1200);
    expect(config.zeroFrequency, 1200);
    expect(config.oneFrequency, 2400);
    expect(config.samplesPerBit, 40);
  });

  test('default uses the V.23 phone-call channel', () {
    const Bfsk config = Bfsk();
    expect(config.sampleRate, 48000);
    expect(config.baudRate, 1200);
    expect(config.zeroFrequency, 2100);
    expect(config.oneFrequency, 1300);
    expect(config.samplesPerBit, 40);
  });

  test('poor-quality preset provides the low-speed fallback channel', () {
    const Bfsk config = Bfsk.poorQuality();
    expect(config.sampleRate, 8000);
    expect(config.baudRate, 100);
    expect(config.zeroFrequency, 1200);
    expect(config.oneFrequency, 2200);
    expect(config.samplesPerBit, 80);
  });

  test('robust remains an alias for the poor-quality preset', () {
    const Bfsk robust = Bfsk.robust();
    const Bfsk poorQuality = Bfsk.poorQuality();
    expect(robust.sampleRate, poorQuality.sampleRate);
    expect(robust.baudRate, poorQuality.baudRate);
    expect(robust.zeroFrequency, poorQuality.zeroFrequency);
    expect(robust.oneFrequency, poorQuality.oneFrequency);
  });
}
