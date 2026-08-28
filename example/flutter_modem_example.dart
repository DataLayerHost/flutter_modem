import 'package:flutter_modem/flutter_modem.dart';

void main() {
  final samples = BfskEncoder().encode(const [0x48, 0x69]);
  print('Generated ${samples.length} PCM samples.');
}
