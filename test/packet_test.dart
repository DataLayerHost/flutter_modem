import 'package:dart_modem/dart_modem.dart';
import 'package:test/test.dart';

void main() {
  test('packet framing round-trips arbitrary bytes', () {
    final Packet decoded =
        Packet.decode(Packet(<int>[0, 1, 127, 255]).encode());
    expect(decoded.version, Packet.currentVersion);
    expect(decoded.payload, <int>[0, 1, 127, 255]);
  });

  test('rejects corrupt packets', () {
    final List<int> encoded = Packet(<int>[1, 2, 3]).encode();
    encoded[Packet.headerLength] ^= 1;
    expect(() => Packet.decode(encoded), throwsFormatException);
  });
}
