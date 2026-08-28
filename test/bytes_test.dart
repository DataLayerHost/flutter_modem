import 'package:flutter_modem/flutter_modem.dart';
import 'package:test/test.dart';

void main() {
  test('hex helpers round-trip', () {
    expect(hexToBytes('00 aa FF'), <int>[0, 170, 255]);
    expect(bytesToHex(<int>[0, 170, 255]), '00aaff');
    expect(bytesToHex(<int>[0, 170, 255], uppercase: true), '00AAFF');
  });
}
