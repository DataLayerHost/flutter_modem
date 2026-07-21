import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../checksum/crc32.dart';
import '../util/byte_reader.dart';
import '../util/byte_writer.dart';
import 'envelope_exception.dart';
import 'transaction_envelope.dart';

abstract final class EnvelopeCodec {
  static const int headerLength = 54;
  static const int fixedLength = 58;
  static const List<int> _magic = <int>[0x56, 0x54, 0x58, 0x31];

  static Uint8List encode(VoiceTxEnvelope envelope) {
    final transaction = envelope.transaction;
    final writer = ByteWriter(fixedLength + transaction.length - 4);
    writer.writeBytes(_magic);
    writer.writeUint8(envelope.protocolVersion);
    writer.writeUint16(envelope.blockchainId);
    writer.writeUint16(envelope.networkId);
    writer.writeUint8(envelope.flags);
    writer.writeUint64(envelope.messageId);
    writer.writeUint32(transaction.length);
    writer.writeBytes(envelope.transactionHash);
    writer.writeBytes(transaction);
    final withoutCrc = writer.takeBytes();
    final result = ByteWriter(fixedLength + transaction.length)
      ..writeBytes(withoutCrc)
      ..writeUint32(Crc32.compute(Uint8List.fromList(withoutCrc)));
    return result.takeBytes();
  }

  static VoiceTxEnvelope decode(Uint8List bytes,
      {required int maximumTransactionSize}) {
    if (maximumTransactionSize < 1) {
      throw ArgumentError.value(
          maximumTransactionSize, 'maximumTransactionSize');
    }
    if (bytes.length < fixedLength) {
      throw const VoiceTxEnvelopeException(
          VoiceTxProtocolError.invalidLength, 'Truncated envelope header');
    }
    try {
      final reader = ByteReader(bytes);
      final magic = reader.readBytes(4);
      if (!_equal(magic, _magic)) {
        throw const VoiceTxEnvelopeException(
            VoiceTxProtocolError.invalidMagic, 'Invalid envelope magic');
      }
      final version = reader.readUint8();
      if (version != VoiceTxEnvelope.currentVersion) {
        throw const VoiceTxEnvelopeException(
            VoiceTxProtocolError.unsupportedVersion,
            'Unsupported envelope version');
      }
      final blockchainId = reader.readUint16();
      final networkId = reader.readUint16();
      final flags = reader.readUint8();
      if (flags != 0) {
        throw const VoiceTxEnvelopeException(
            VoiceTxProtocolError.malformedEnvelope, 'Unknown required flags');
      }
      final messageId = reader.readUint64();
      final length = reader.readUint32();
      if (length == 0 || length > maximumTransactionSize) {
        throw const VoiceTxEnvelopeException(
            VoiceTxProtocolError.invalidLength, 'Invalid transaction length');
      }
      if (bytes.length != fixedLength + length) {
        throw const VoiceTxEnvelopeException(VoiceTxProtocolError.invalidLength,
            'Envelope length does not match declaration');
      }
      final hash = reader.readBytes(32);
      final transaction = reader.readBytes(length);
      final crc = reader.readUint32();
      if (crc != Crc32.compute(bytes, 0, bytes.length - 4)) {
        throw const VoiceTxEnvelopeException(
            VoiceTxProtocolError.invalidCrc, 'Envelope CRC mismatch');
      }
      final computedHash = sha256.convert(transaction).bytes;
      if (!_equal(hash, computedHash)) {
        throw const VoiceTxEnvelopeException(
            VoiceTxProtocolError.invalidHash, 'Transaction SHA-256 mismatch');
      }
      return VoiceTxEnvelope.decoded(
          protocolVersion: version,
          blockchainId: blockchainId,
          networkId: networkId,
          flags: flags,
          messageId: messageId,
          transactionHash: hash,
          transaction: transaction);
    } on VoiceTxEnvelopeException {
      rethrow;
    } on FormatException {
      throw const VoiceTxEnvelopeException(
          VoiceTxProtocolError.invalidLength, 'Truncated envelope');
    }
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var index = 0; index < a.length; index++) {
      result |= a[index] ^ b[index];
    }
    return result == 0;
  }
}
