import 'package:flutter_modem/flutter_modem.dart';
import 'package:test/test.dart';

void main() {
  test('finds preamble and sync after unrelated bits', () {
    final FrameSynchronizer synchronizer = FrameSynchronizer(preambleBits: 16);
    final List<int> bits = <int>[0, 0, 1, ...Preamble.bits(16)];
    for (int shift = Preamble.syncWordBits - 1; shift >= 0; shift--) {
      bits.add((Preamble.syncWord >> shift) & 1);
    }
    final List<bool> results = bits.map(synchronizer.addBit).toList();
    expect(results.where((bool value) => value).length, 1);
    expect(results.last, isTrue);
  });
}
