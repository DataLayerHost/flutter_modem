import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_modem/flutter_modem.dart';

final FlutterModem modem = FlutterModem();
final Int16List preparedTransactionPcm = modem.encode(
  utf8.encode('Prepared transaction'),
);
final ReadySignalDetector readyDetector = ReadySignalDetector(
  modemDecoder: modem.createStreamingDecoder(),
);

void onMicrophonePcm(Int16List chunk) {
  for (final ReadySignalEvent event in readyDetector.add(chunk)) {
    if (event is ReadySignalDetected && !event.isDuplicate) {
      final Duration delay = event.signal.guardDelay;
      print(
        'READY received; stop capture, wait $delay, then play '
        '${preparedTransactionPcm.length} prepared PCM samples.',
      );
    }
  }
}

void main() {
  // A Flutter/native layer owns real call control, audio I/O, and wall-clock
  // waiting. Here a generated READY signal stands in for microphone capture.
  final Int16List receivedAudio = ReadySignalEncoder(modem: modem).encode(
    const ReadySignal(sessionId: 0x12345678),
  );
  for (int offset = 0; offset < receivedAudio.length; offset += 257) {
    final int end = (offset + 257).clamp(0, receivedAudio.length);
    onMicrophonePcm(receivedAudio.sublist(offset, end));
  }
}
