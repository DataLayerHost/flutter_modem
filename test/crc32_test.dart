import 'dart:convert';

import 'package:dart_modem/dart_modem.dart';
import 'package:test/test.dart';

void main() {
  test('matches the standard CRC-32 check value', () {
    expect(Crc32.compute(utf8.encode('123456789')), 0xcbf43926);
  });
}
