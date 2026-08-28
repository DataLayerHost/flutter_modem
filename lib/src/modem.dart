import 'dart:typed_data';

import 'config.dart';
import 'decoder/bfsk_decoder.dart';
import 'decoder/protocol_decoder.dart';
import 'encoder/bfsk_encoder.dart';
import 'protocol/modem_protocol.dart';

/// Convenient facade for encoding and creating matching decoders.
final class FlutterModem {
  FlutterModem({
    this.modulation = const Bfsk(),
    this.protocol = const VoiceTxModemProtocol(),
  });

  final Bfsk modulation;

  /// Application protocol layered above the modem packet transport.
  ///
  /// Pass `null` (or [NoModemProtocol]) to transmit application bytes without
  /// Voice TX framing, or supply another [ModemProtocol] implementation.
  final ModemProtocol? protocol;

  Int16List encode(List<int> bytes) {
    final BfskEncoder encoder = BfskEncoder(config: modulation);
    final ModemProtocol? selectedProtocol = protocol;
    final Iterable<List<int>> packets;
    if (selectedProtocol == null) {
      packets = <List<int>>[bytes];
    } else {
      packets = selectedProtocol.encode(bytes).cast<List<int>>();
    }
    final BytesBuilder pcm = BytesBuilder(copy: false);
    for (final List<int> packet in packets) {
      final Int16List encoded = encoder.encode(packet);
      pcm.add(encoded.buffer.asUint8List(
        encoded.offsetInBytes,
        encoded.lengthInBytes,
      ));
    }
    final Uint8List bytesOut = pcm.takeBytes();
    return Int16List.view(
      bytesOut.buffer,
      bytesOut.offsetInBytes,
      bytesOut.lengthInBytes ~/ Int16List.bytesPerElement,
    );
  }

  ModemFrameDecoder createDecoder() {
    final BfskDecoder decoder = BfskDecoder(config: modulation);
    final ModemProtocol? selectedProtocol = protocol;
    return selectedProtocol == null
        ? decoder
        : ProtocolModemDecoder(
            modemDecoder: decoder,
            protocolDecoder: selectedProtocol.createDecoder(),
          );
  }

  StreamingFlutterModemDecoder createStreamingDecoder() =>
      StreamingFlutterModemDecoder(createDecoder());
}
