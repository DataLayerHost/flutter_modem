import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_modem/flutter_modem.dart';

void main() {
  final Int16List pcm = BfskEncoder().encode(utf8.encode('Hello'));
  print('Encoded ${pcm.length} signed Int16 PCM samples.');
}
