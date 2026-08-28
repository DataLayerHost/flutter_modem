import 'dart:typed_data';

import 'package:flutter_modem/flutter_modem.dart';
import 'package:test/test.dart';

void main() {
  test('Voice TX is the default protocol', () {
    final FlutterModem modem = FlutterModem();
    final Uint8List payload = Uint8List.fromList(<int>[1, 2, 3, 4]);

    final List<ModemFrame> frames =
        modem.createDecoder().feed(modem.encode(payload));

    expect(modem.protocol, isA<VoiceTxModemProtocol>());
    expect(frames, hasLength(1));
    expect(frames.single.payload, payload);
  });

  test('null protocol sends bytes without application framing', () {
    final FlutterModem modem = FlutterModem(protocol: null);
    final Uint8List payload = Uint8List.fromList(<int>[5, 6, 7]);

    final List<ModemFrame> frames =
        modem.createDecoder().feed(modem.encode(payload));

    expect(frames.single.payload, payload);
  });

  test('a custom protocol can replace Voice TX', () {
    final FlutterModem modem = FlutterModem(protocol: const _PrefixProtocol());
    final Uint8List payload = Uint8List.fromList(<int>[8, 9]);

    final List<ModemFrame> frames =
        modem.createDecoder().feed(modem.encode(payload));

    expect(frames.single.payload, payload);
  });
}

final class _PrefixProtocol implements ModemProtocol {
  const _PrefixProtocol();

  @override
  Iterable<Uint8List> encode(List<int> payload) => <Uint8List>[
        Uint8List.fromList(<int>[0xaa, ...payload]),
      ];

  @override
  ModemProtocolDecoder createDecoder() => _PrefixProtocolDecoder();
}

final class _PrefixProtocolDecoder implements ModemProtocolDecoder {
  @override
  Iterable<Uint8List> decode(List<int> packet) {
    if (packet.isEmpty || packet.first != 0xaa) {
      throw const FormatException('Missing custom protocol prefix.');
    }
    return <Uint8List>[Uint8List.fromList(packet.sublist(1))];
  }

  @override
  void reset() {}
}
