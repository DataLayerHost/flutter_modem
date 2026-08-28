import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_modem/flutter_modem.dart';

void main() {
  final Random random = Random.secure();
  final Uint8List payload =
      Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  final Int16List pcm = FlutterModem().encode(payload);
  print('Payload: ${bytesToHex(payload)}');
  print('PCM samples: ${pcm.length}');
}
