import 'dart:typed_data';

import '../config.dart';
import '../protocol/packet.dart';
import '../protocol/preamble.dart';
import '../util/bits.dart';
import 'tone_generator.dart';

/// Encodes packets as continuous-phase binary frequency-shift keyed PCM.
final class BfskEncoder {
  BfskEncoder({this.config = const Bfsk()});

  final Bfsk config;

  int get sampleRate => config.sampleRate;
  int get baudRate => config.baudRate;
  double get zeroFrequency => config.zeroFrequency;
  double get oneFrequency => config.oneFrequency;
  int get samplesPerBit => config.samplesPerBit;

  Int16List encode(List<int> payload) {
    if (payload.length > config.maximumPayloadLength) {
      throw ArgumentError.value(
          payload.length, 'payload', 'Payload is too large.');
    }
    final Uint8List packet = Packet(payload).encode();
    final int bitCount = config.carrierBits +
        config.preambleBits +
        Preamble.syncWordBits +
        packet.length * 8;
    final Int16List pcm = Int16List(bitCount * samplesPerBit);
    final ToneGenerator generator = ToneGenerator(
      sampleRate: sampleRate,
      amplitude: config.amplitude,
    );
    int offset = 0;

    void writeBit(int bit) {
      generator.write(
        pcm,
        offset,
        samplesPerBit,
        bit == 0 ? zeroFrequency : oneFrequency,
      );
      offset += samplesPerBit;
    }

    for (int index = 0; index < config.carrierBits; index++) {
      writeBit(1);
    }
    for (int index = 0; index < config.preambleBits; index++) {
      writeBit(Preamble.bitAt(index));
    }
    for (int shift = Preamble.syncWordBits - 1; shift >= 0; shift--) {
      writeBit((Preamble.syncWord >> shift) & 1);
    }
    forEachBit(packet, writeBit);
    return pcm;
  }
}
