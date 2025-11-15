import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// Lightweight wrapper providing a PDFBox-like `MessageDigest` API on top of
/// `package:crypto` hashes.
class MessageDigest {
  MessageDigest._(this._hash);

  final crypto.Hash _hash;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  Uint8List? _result;
  bool _closed = false;

  /// Adds a chunk of bytes to the digest computation.
  void update(List<int> data) {
    if (_closed) {
      throw StateError('MessageDigest already closed');
    }
    _buffer.add(data);
  }

  /// Completes the hash calculation and returns the digest as bytes.
  Uint8List digest() {
    if (_result != null) {
      return Uint8List.fromList(_result!);
    }
    final digest = _hash.convert(_buffer.takeBytes());
    _closed = true;
    _result = Uint8List.fromList(digest.bytes);
    return Uint8List.fromList(_result!);
  }
}

/// Factory helpers mirroring Apache PDFBox' utility class.
class MessageDigests {
  MessageDigests._();

  static MessageDigest getMD5() => MessageDigest._(crypto.md5);

  static MessageDigest getSHA1() => MessageDigest._(crypto.sha1);

  static MessageDigest getSHA256() => MessageDigest._(crypto.sha256);
}
