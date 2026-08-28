import 'dart:typed_data';

import 'package:flutter_modem/flutter_modem.dart';

void main() {
  final FlutterModem modem = FlutterModem();
  final RepeatingReadySignalEncoder repeater = RepeatingReadySignalEncoder(
    modem: modem,
    ready: const ReadySignal(
      sessionId: 0x12345678,
      guardDelay: Duration(milliseconds: 500),
      receiverTimeout: Duration(seconds: 10),
    ),
    repeatInterval: const Duration(milliseconds: 300),
    maximumRepeats: 20,
  );

  for (final Int16List pcm in repeater.chunks()) {
    sendToAudioOutput(pcm);
    if (transactionPreambleDetected()) {
      break;
    }
  }
}

void sendToAudioOutput(Int16List pcm) {
  // A server/Asterisk adapter writes this block at the modem sample rate.
  print('Send ${pcm.length} PCM samples');
}

bool transactionPreambleDetected() {
  // The host integration supplies this state from its incoming audio path.
  return false;
}
