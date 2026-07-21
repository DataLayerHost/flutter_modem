import '../protocol/preamble.dart';

/// Bit-level synchronizer for the alternating preamble and sync word.
final class FrameSynchronizer {
  FrameSynchronizer({required this.preambleBits})
      : assert(preambleBits >= 8),
        _pattern = <int>[
          ...Preamble.bits(preambleBits),
          for (int shift = Preamble.syncWordBits - 1; shift >= 0; shift--)
            (Preamble.syncWord >> shift) & 1,
        ];

  final int preambleBits;
  final List<int> _pattern;
  final List<int> _window = <int>[];

  void reset() => _window.clear();

  /// Returns true exactly when the complete synchronization pattern is seen.
  bool addBit(int bit) {
    _window.add(bit & 1);
    if (_window.length > _pattern.length) {
      _window.removeAt(0);
    }
    if (_window.length != _pattern.length) {
      return false;
    }
    for (int index = 0; index < _pattern.length; index++) {
      if (_window[index] != _pattern[index]) {
        return false;
      }
    }
    _window.clear();
    return true;
  }
}
