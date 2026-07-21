import 'dart:typed_data';

import '../voice_tx/envelope/transaction_envelope.dart';
import '../voice_tx/packet/voice_tx_packet.dart';
import '../voice_tx/stream/assembly_event.dart';
import '../voice_tx/stream/packet_assembler.dart';
import '../voice_tx/stream/packetizer.dart';

/// Application-level framing layered above the acoustic modem transport.
///
/// One application payload may produce multiple independently transmitted
/// packets. Decoders are stateful so protocols can reassemble those packets.
abstract interface class ModemProtocol {
  Iterable<Uint8List> encode(List<int> payload);

  ModemProtocolDecoder createDecoder();
}

/// Stateful inverse of a [ModemProtocol].
abstract interface class ModemProtocolDecoder {
  Iterable<Uint8List> decode(List<int> packet);

  void reset();
}

/// Version 1 Voice Transaction Protocol, used by [DartModem] by default.
///
/// The input to [encode] is an already-signed, publicly broadcastable
/// transaction. It is enveloped, hashed, checksummed, and split into bounded
/// Voice TX DATA packets before acoustic encoding.
final class VoiceTxModemProtocol implements ModemProtocol {
  const VoiceTxModemProtocol({
    this.blockchainId = 0,
    this.networkId = 0,
    this.maximumPacketPayloadSize = 24,
    this.maximumTransactionSize = 1024 * 1024,
    this.maximumPacketCount = 0xffff,
  });

  final int blockchainId;
  final int networkId;
  final int maximumPacketPayloadSize;
  final int maximumTransactionSize;
  final int maximumPacketCount;

  @override
  Iterable<Uint8List> encode(List<int> payload) sync* {
    final VoiceTxEnvelope envelope = VoiceTxEnvelope.create(
      blockchainId: blockchainId,
      networkId: networkId,
      transaction: Uint8List.fromList(payload),
    );
    final VoiceTxTransmission transmission = VoiceTxPacketizer(
      maximumPayloadSize: maximumPacketPayloadSize,
    ).packetize(envelope);
    if (transmission.totalPacketCount > maximumPacketCount) {
      throw StateError('Voice TX packet count exceeds the configured limit.');
    }
    for (final VoiceTxPacket packet in transmission.packets) {
      yield packet.encode();
    }
  }

  @override
  ModemProtocolDecoder createDecoder() => _VoiceTxModemProtocolDecoder(this);
}

final class _VoiceTxModemProtocolDecoder implements ModemProtocolDecoder {
  _VoiceTxModemProtocolDecoder(VoiceTxModemProtocol protocol)
      : _protocol = protocol,
        _assembler = _createAssembler(protocol);

  final VoiceTxModemProtocol _protocol;
  VoiceTxPacketAssembler _assembler;

  static VoiceTxPacketAssembler _createAssembler(
    VoiceTxModemProtocol protocol,
  ) =>
      VoiceTxPacketAssembler(
        maximumTransactionSize: protocol.maximumTransactionSize,
        maximumPacketCount: protocol.maximumPacketCount,
        maximumPacketPayloadSize: protocol.maximumPacketPayloadSize,
        maximumBufferedBytes: protocol.maximumTransactionSize + 58,
      );

  @override
  Iterable<Uint8List> decode(List<int> packet) sync* {
    final VoiceTxPacket decoded = VoiceTxPacket.decode(
      Uint8List.fromList(packet),
      maximumPayloadSize: _protocol.maximumPacketPayloadSize,
    );
    final VoiceTxAssemblyEvent event = _assembler.accept(decoded);
    if (event case VoiceTxTransactionComplete(:final transaction)) {
      yield transaction;
      _assembler = _createAssembler(_protocol);
    }
  }

  @override
  void reset() => _assembler = _createAssembler(_protocol);
}

/// Identity application protocol.
///
/// This is equivalent to passing `protocol: null` to [DartModem], and is
/// useful where a concrete [ModemProtocol] value is required.
final class NoModemProtocol implements ModemProtocol {
  const NoModemProtocol();

  @override
  Iterable<Uint8List> encode(List<int> payload) =>
      <Uint8List>[Uint8List.fromList(payload)];

  @override
  ModemProtocolDecoder createDecoder() => _NoModemProtocolDecoder();
}

final class _NoModemProtocolDecoder implements ModemProtocolDecoder {
  @override
  Iterable<Uint8List> decode(List<int> packet) =>
      <Uint8List>[Uint8List.fromList(packet)];

  @override
  void reset() {}
}
