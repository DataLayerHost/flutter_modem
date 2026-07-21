import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../util/hex_codec.dart';
import 'envelope_codec.dart';
import 'envelope_exception.dart';

/// Immutable, validated envelope for an already-signed transaction.
final class VoiceTxEnvelope {
  VoiceTxEnvelope._({
    required this.protocolVersion,
    required this.blockchainId,
    required this.networkId,
    required this.flags,
    required this.messageId,
    required Uint8List transactionHash,
    required Uint8List transaction,
  })  : _transactionHash = Uint8List.fromList(transactionHash),
        _transaction = Uint8List.fromList(transaction);

  static const int currentVersion = 1;
  final int protocolVersion;
  final int blockchainId;
  final int networkId;
  final int flags;
  final int messageId;
  final Uint8List _transactionHash;
  final Uint8List _transaction;

  Uint8List get transactionHash => Uint8List.fromList(_transactionHash);
  Uint8List get transaction => Uint8List.fromList(_transaction);

  /// Creates an envelope, defensively copying [transaction].
  factory VoiceTxEnvelope.create({
    required int blockchainId,
    required int networkId,
    required Uint8List transaction,
    int? messageId,
    int flags = 0,
  }) {
    if (transaction.isEmpty) {
      throw const VoiceTxEnvelopeException(
        VoiceTxProtocolError.invalidLength,
        'Transaction must not be empty',
      );
    }
    if (blockchainId < 0 ||
        blockchainId > 0xffff ||
        networkId < 0 ||
        networkId > 0xffff) {
      throw const VoiceTxEnvelopeException(
          VoiceTxProtocolError.invalidLength, 'Identifier is outside uint16');
    }
    if (flags != 0) {
      throw const VoiceTxEnvelopeException(
          VoiceTxProtocolError.malformedEnvelope, 'Unknown required flags');
    }
    final id = messageId ?? _secureMessageId();
    if (id < 0) {
      throw const VoiceTxEnvelopeException(
          VoiceTxProtocolError.invalidLength, 'Message ID is outside uint64');
    }
    final copy = Uint8List.fromList(transaction);
    return VoiceTxEnvelope._(
      protocolVersion: currentVersion,
      blockchainId: blockchainId,
      networkId: networkId,
      flags: flags,
      messageId: id,
      transactionHash: Uint8List.fromList(sha256.convert(copy).bytes),
      transaction: copy,
    );
  }

  static int _secureMessageId() {
    final random = Random.secure();
    // Dart VM integers are signed 64-bit values. Keep the high bit clear while
    // retaining 63 bits of CSPRNG entropy and a valid uint64 wire value.
    return (random.nextInt(1 << 31) << 32) | random.nextInt(1 << 32);
  }

  Uint8List encode() => EnvelopeCodec.encode(this);

  static VoiceTxEnvelope decode(Uint8List bytes,
          {int maximumTransactionSize = 1024 * 1024}) =>
      EnvelopeCodec.decode(bytes,
          maximumTransactionSize: maximumTransactionSize);

  static VoiceTxEnvelope decoded(
          {required int protocolVersion,
          required int blockchainId,
          required int networkId,
          required int flags,
          required int messageId,
          required Uint8List transactionHash,
          required Uint8List transaction}) =>
      VoiceTxEnvelope._(
          protocolVersion: protocolVersion,
          blockchainId: blockchainId,
          networkId: networkId,
          flags: flags,
          messageId: messageId,
          transactionHash: transactionHash,
          transaction: transaction);

  @override
  bool operator ==(Object other) =>
      other is VoiceTxEnvelope &&
      protocolVersion == other.protocolVersion &&
      blockchainId == other.blockchainId &&
      networkId == other.networkId &&
      flags == other.flags &&
      messageId == other.messageId &&
      _bytesEqual(_transactionHash, other._transactionHash) &&
      _bytesEqual(_transaction, other._transaction);

  @override
  int get hashCode => Object.hash(
      protocolVersion,
      blockchainId,
      networkId,
      flags,
      messageId,
      Object.hashAll(_transactionHash),
      Object.hashAll(_transaction));

  @override
  String toString() =>
      'VoiceTxEnvelope(messageId: $messageId, blockchainId: $blockchainId, networkId: $networkId, transactionLength: ${_transaction.length}, hash: ${bytesToHex(_transactionHash.take(6))}…)';
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var index = 0; index < a.length; index++) {
    difference |= a[index] ^ b[index];
  }
  return difference == 0;
}
