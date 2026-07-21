import 'dart:typed_data';

import '../config.dart';
import '../protocol/frame.dart';
import '../protocol/packet.dart';
import '../util/bytes.dart';
import 'goertzel.dart';
import 'synchronizer.dart';

/// Synchronous interface implemented by incremental modem frame decoders.
abstract interface class ModemFrameDecoder {
  List<ModemFrame> feed(Iterable<int> pcm);

  void reset();
}

/// Incremental fixed-rate BFSK decoder using two Goertzel detectors.
final class BfskDecoder implements ModemFrameDecoder {
  BfskDecoder({this.config = const Bfsk()})
      : _zero = Goertzel(
          sampleRate: config.sampleRate,
          frequency: config.zeroFrequency,
        ),
        _one = Goertzel(
          sampleRate: config.sampleRate,
          frequency: config.oneFrequency,
        ),
        _synchronizer = FrameSynchronizer(preambleBits: config.preambleBits),
        _symbol = Int16List(config.samplesPerBit);

  final Bfsk config;
  final Goertzel _zero;
  final Goertzel _one;
  final FrameSynchronizer _synchronizer;
  final Int16List _symbol;
  int _symbolOffset = 0;
  bool _receivingPacket = false;
  int _currentByte = 0;
  int _bitOffset = 0;
  final List<int> _packetBytes = <int>[];
  int? _expectedPacketLength;

  int get sampleRate => config.sampleRate;
  int get baudRate => config.baudRate;
  double get zeroFrequency => config.zeroFrequency;
  double get oneFrequency => config.oneFrequency;
  int get samplesPerBit => config.samplesPerBit;

  /// Consumes any number of PCM samples and returns all completed valid frames.
  @override
  List<ModemFrame> feed(Iterable<int> pcm) {
    final List<ModemFrame> frames = <ModemFrame>[];
    for (final int sample in pcm) {
      _symbol[_symbolOffset++] = sample.clamp(-32768, 32767);
      if (_symbolOffset == _symbol.length) {
        _symbolOffset = 0;
        _processBit(_detectBit(), frames);
      }
    }
    return frames;
  }

  @override
  void reset() {
    _symbolOffset = 0;
    _synchronizer.reset();
    _resetPacket();
  }

  int _detectBit() => _one.power(_symbol) > _zero.power(_symbol) ? 1 : 0;

  void _processBit(int bit, List<ModemFrame> frames) {
    if (!_receivingPacket) {
      if (_synchronizer.addBit(bit)) {
        _receivingPacket = true;
      }
      return;
    }
    _currentByte = (_currentByte << 1) | bit;
    _bitOffset++;
    if (_bitOffset != 8) {
      return;
    }
    _packetBytes.add(_currentByte);
    _currentByte = 0;
    _bitOffset = 0;

    if (_packetBytes.length == Packet.headerLength) {
      if (!_validHeader()) {
        _resetPacket();
        return;
      }
      final int payloadLength = readUint32BigEndian(_packetBytes, 5);
      _expectedPacketLength =
          Packet.headerLength + payloadLength + Packet.crcLength;
    }
    if (_expectedPacketLength == _packetBytes.length) {
      try {
        frames.add(ModemFrame(Packet.decode(
          _packetBytes,
          maximumPayloadLength: config.maximumPayloadLength,
        )));
      } on FormatException {
        // Corrupt frames are deliberately discarded.
      }
      _resetPacket();
    }
  }

  bool _validHeader() {
    for (int index = 0; index < Packet.magic.length; index++) {
      if (_packetBytes[index] != Packet.magic[index]) {
        return false;
      }
    }
    if (_packetBytes[4] != Packet.currentVersion) {
      return false;
    }
    return readUint32BigEndian(_packetBytes, 5) <= config.maximumPayloadLength;
  }

  void _resetPacket() {
    _receivingPacket = false;
    _currentByte = 0;
    _bitOffset = 0;
    _packetBytes.clear();
    _expectedPacketLength = null;
    _synchronizer.reset();
  }
}
