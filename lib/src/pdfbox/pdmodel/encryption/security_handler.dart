import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../cos/cos_array.dart';
import '../pd_document.dart';
import 'access_permission.dart';
import 'decryption_material.dart';
import 'message_digests.dart';
import 'pd_encryption.dart';
import 'protection_policy.dart';
import 'rc4_cipher.dart';

/// Base class for PDF security handlers.
///
/// This mirrors the structure of Apache PDFBox' `SecurityHandler`, exposing the
/// knobs required by both password and certificate based handlers. Portions of
/// the encryption workflow (AES, stream quoting) still carry TODO markers until
/// the full Java implementation is ported.
abstract class SecurityHandler<T extends ProtectionPolicy> {
  SecurityHandler({T? protectionPolicy}) {
    if (protectionPolicy != null) {
      setProtectionPolicy(protectionPolicy);
    }
  }

  static final Uint8List _aesSalt =
      Uint8List.fromList(<int>[0x73, 0x41, 0x6c, 0x54]);

  int _keyLength = ProtectionPolicy.defaultKeyLength;
  bool _decryptMetadata = true;
  bool _useAES = false;
  T? _protectionPolicy;
  AccessPermission? _currentAccessPermission;
  Uint8List? _encryptionKey;

  final RC4Cipher _rc4 = RC4Cipher();

  /// Length of the file encryption key in bits.
  int get keyLength => _keyLength;

  set keyLength(int value) => _keyLength = value;

  /// Whether document metadata should be decrypted.
  bool get decryptMetadata => _decryptMetadata;

  set decryptMetadata(bool value) => _decryptMetadata = value;

  /// True when the handler should use AES based algorithms.
  bool get isAES => _useAES;

  set isAES(bool value) => _useAES = value;

  /// Returns the configured protection policy, if any.
  T? get protectionPolicy => _protectionPolicy;

  /// Returns true when a protection policy has been associated with this
  /// handler instance.
  bool get hasProtectionPolicy => _protectionPolicy != null;

  /// Associates a protection policy, updating internal switches such as the key
  /// length and AES preference to mirror the Java implementation.
  void setProtectionPolicy(T policy) {
    _protectionPolicy = policy;
    keyLength = policy.encryptionKeyLength;
    if (policy.encryptionKeyLength >= 256) {
      _useAES = true;
    } else if (policy.encryptionKeyLength == 128) {
      _useAES = policy.preferAes;
    } else {
      _useAES = false;
    }
  }

  /// Clears the protection policy reference.
  void clearProtectionPolicy() {
    _protectionPolicy = null;
  }

  /// Returns the permissions granted to the currently authenticated entity.
  AccessPermission? get currentAccessPermission => _currentAccessPermission;

  /// Marks [permission] as read-only and stores it for subsequent checks.
  void setCurrentAccessPermission(AccessPermission permission) {
    permission.setReadOnly();
    _currentAccessPermission = permission;
  }

  /// Returns a defensive copy of the file encryption key, when available.
  Uint8List? get encryptionKey =>
      _encryptionKey == null ? null : Uint8List.fromList(_encryptionKey!);

  /// Stores the file encryption key (expressed in bytes rather than bits).
  void setEncryptionKey(List<int> key) {
    _encryptionKey = Uint8List.fromList(key);
  }

  /// Removes the currently stored encryption key.
  void clearEncryptionKey() {
    _encryptionKey = null;
  }

  /// True when an encryption key has been initialised for this handler.
  bool get hasEncryptionKey => _encryptionKey != null;

  /// Computes the encryption version number based on the configured key
  /// length and protection policy preferences. Mirrors the logic present in
  /// Apache PDFBox' base handler.
  @protected
  int computeVersionNumber() {
    if (_keyLength == 40) {
      return 1;
    }
    if (_keyLength == 128 && (protectionPolicy?.preferAes ?? false)) {
      return 4;
    }
    if (_keyLength == 256) {
      return 5;
    }
    return 2;
  }

  /// Ensures an encryption key is available before continuing with low level
  /// computations.
  @protected
  Uint8List get encryptionKeyOrThrow {
    final key = _encryptionKey;
    if (key == null) {
      throw StateError('Encryption key has not been initialised');
    }
    return key;
  }

  /// Prepares the supplied document for encryption using the configured
  /// protection policy.
  void prepareDocumentForEncryption(PDDocument document);

  /// Prepares the handler for decrypting an existing document.
  void prepareForDecryption(
    PDEncryption encryption,
    COSArray? documentIdArray,
    DecryptionMaterial decryptionMaterial,
  );

  /// Derives the object specific key used for RC4/AES content encryption.
  /// Exposed to the test-suite while the full encryption pipeline is ported.
  @visibleForTesting
  Uint8List deriveObjectKey(
    int objectNumber,
    int generationNumber, {
    Uint8List? baseKey,
  }) {
    final seed = baseKey ?? encryptionKeyOrThrow;
    final buffer = Uint8List(seed.length + 5)
      ..setAll(0, seed)
      ..[seed.length] = objectNumber & 0xff
      ..[seed.length + 1] = (objectNumber >> 8) & 0xff
      ..[seed.length + 2] = (objectNumber >> 16) & 0xff
      ..[seed.length + 3] = generationNumber & 0xff
      ..[seed.length + 4] = (generationNumber >> 8) & 0xff;
    final digest = MessageDigests.getMD5();
    digest.update(buffer);
    if (_useAES) {
      digest.update(_aesSalt);
    }
    final hashed = digest.digest();
    final length = math.min(seed.length + 5, 16);
    return Uint8List.fromList(hashed.sublist(0, length));
  }

  /// Applies RC4 using the derived object key. This method is intentionally
  /// visible for tests until the full encryption/decryption pipeline is ported.
  @visibleForTesting
  Uint8List applyRC4ToBytes(
    Uint8List data,
    int objectNumber,
    int generationNumber,
  ) {
    final objectKey = deriveObjectKey(objectNumber, generationNumber);
    _rc4.setKey(objectKey);
    return _rc4.process(data);
  }
}
