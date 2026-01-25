import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:pointycastle/export.dart' as pc;

import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_stream.dart';
import '../../cos/cos_string.dart';
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
/// knobs required by both password and certificate based handlers, including
/// stream/string encryption helpers for RC4 and AES.
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
  COSName? _streamFilterName;
  COSName? _stringFilterName;
  math.Random? _customSecureRandom;

  final RC4Cipher _rc4 = RC4Cipher();
  final Set<COSBase> _processedObjects = HashSet<COSBase>.identity();

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

  /// Returns the crypt filter name to be used for streams (if any).
  COSName? get streamFilterName => _streamFilterName;

  /// Returns the crypt filter name to be used for strings (if any).
  COSName? get stringFilterName => _stringFilterName;

  /// Overrides the stream filter name.
  @protected
  void setStreamFilterName(COSName? value) {
    _streamFilterName = value;
  }

  /// Overrides the string filter name.
  @protected
  void setStringFilterName(COSName? value) {
    _stringFilterName = value;
  }

  /// Allows callers to provide a custom secure random for AES IV generation.
  void setCustomSecureRandom(math.Random random) {
    _customSecureRandom = random;
  }

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

  /// Decrypts a COS object using the supplied object and generation numbers.
  COSBase decryptObject(COSBase obj, int objectNumber, int generationNumber) {
    if (obj is COSString) {
      if (_processedObjects.contains(obj)) {
        return obj;
      }
      final decrypted = _decryptString(obj, objectNumber, generationNumber);
      _processedObjects.add(decrypted);
      return decrypted;
    }
    if (obj is COSStream) {
      if (_processedObjects.contains(obj)) {
        return obj;
      }
      _processedObjects.add(obj);
      decryptStream(obj, objectNumber, generationNumber);
      return obj;
    }
    if (obj is COSDictionary) {
      _decryptDictionary(obj, objectNumber, generationNumber);
    } else if (obj is COSArray) {
      _decryptArray(obj, objectNumber, generationNumber);
    }
    return obj;
  }

  /// Decrypts stream data in-place.
  void decryptStream(COSStream stream, int objectNumber, int generationNumber) {
    if (_streamFilterName == COSName.identity) {
      return;
    }
    final type = stream.getCOSName(COSName.type);
    if (!_decryptMetadata && type == COSName.metadata) {
      return;
    }
    if (type == COSName.xref) {
      return;
    }
    if (type == COSName.metadata) {
      final data = stream.encodedBytes(copy: false);
      if (data != null && data.length >= 10) {
        final probe = Uint8List.sublistView(data, 0, 10);
        if (_matchesXPacketProbe(probe)) {
          return;
        }
      }
    }
    _decryptDictionary(stream, objectNumber, generationNumber);
    final data = stream.encodedBytes(copy: false);
    if (data == null || data.isEmpty) {
      return;
    }
    stream.data = _encryptDataBytes(
      data,
      objectNumber,
      generationNumber,
      decrypt: true,
    );
  }

  /// Encrypts stream data in-place.
  void encryptStream(COSStream stream, int objectNumber, int generationNumber) {
    final data = stream.encodedBytes(copy: false);
    if (data == null || data.isEmpty) {
      return;
    }
    stream.data = _encryptDataBytes(
      data,
      objectNumber,
      generationNumber,
      decrypt: false,
    );
  }

  /// Encrypts a string using the object-specific key.
  COSBase encryptString(COSString string, int objectNumber, int generationNumber) {
    final data = string.bytes;
    final encrypted = _encryptDataBytes(
      data,
      objectNumber,
      generationNumber,
      decrypt: false,
    );
    return COSString.fromBytes(encrypted);
  }

  COSBase _decryptString(
    COSString string,
    int objectNumber,
    int generationNumber,
  ) {
    if (_stringFilterName == COSName.identity) {
      return string;
    }
    final decrypted = _encryptDataBytes(
      string.bytes,
      objectNumber,
      generationNumber,
      decrypt: true,
    );
    return COSString.fromBytes(decrypted);
  }

  void _decryptArray(COSArray array, int objectNumber, int generationNumber) {
    for (var i = 0; i < array.length; i++) {
      final value = array.getObject(i);
      if (value is COSString || value is COSArray || value is COSDictionary) {
        array[i] = decryptObject(value, objectNumber, generationNumber);
      }
    }
  }

  void _decryptDictionary(
    COSDictionary dictionary,
    int objectNumber,
    int generationNumber,
  ) {
    if (dictionary.getItem(COSName.cf) != null) {
      return;
    }
    final type = dictionary.getCOSName(COSName.type);
    final isSignature = type == COSName.sig ||
        type == COSName.get('DocTimeStamp') ||
        (dictionary.getDictionaryObject(COSName.contents) is COSString &&
            dictionary.getDictionaryObject(COSName.byteRange) is COSArray);
    final entries = dictionary.entries.toList();
    for (final entry in entries) {
      if (isSignature && entry.key == COSName.contents) {
        continue;
      }
      final value = entry.value;
      if (value is COSString || value is COSArray || value is COSDictionary) {
        dictionary[entry.key] =
            decryptObject(value, objectNumber, generationNumber);
      }
    }
  }

  Uint8List _encryptDataBytes(
    Uint8List data,
    int objectNumber,
    int generationNumber, {
    required bool decrypt,
  }) {
    if (_useAES && encryptionKeyOrThrow.length == 32) {
      return _encryptDataAes256(data, decrypt: decrypt);
    }
    final objectKey = deriveObjectKey(objectNumber, generationNumber);
    if (_useAES) {
      return _encryptDataAesOther(objectKey, data, decrypt: decrypt);
    }
    _rc4.setKey(objectKey);
    return _rc4.process(data);
  }

  Uint8List _encryptDataAes256(Uint8List data, {required bool decrypt}) {
    return _encryptDataAes(encryptionKeyOrThrow, data, decrypt: decrypt);
  }

  Uint8List _encryptDataAesOther(
    Uint8List objectKey,
    Uint8List data, {
    required bool decrypt,
  }) {
    return _encryptDataAes(objectKey, data, decrypt: decrypt);
  }

  Uint8List _encryptDataAes(
    Uint8List key,
    Uint8List data, {
    required bool decrypt,
  }) {
    if (decrypt) {
      if (data.length < 16) {
        throw StateError(
            'AES initialization vector not fully read (${data.length} bytes)');
      }
      final iv = Uint8List.sublistView(data, 0, 16);
      final payload = Uint8List.sublistView(data, 16);
      return _aesCbcProcess(key, iv, payload, forEncryption: false);
    }
    final iv = _randomIv();
    final encrypted = _aesCbcProcess(key, iv, data, forEncryption: true);
    final output = Uint8List(iv.length + encrypted.length);
    output.setRange(0, iv.length, iv);
    output.setRange(iv.length, output.length, encrypted);
    return output;
  }

  Uint8List _aesCbcProcess(
    Uint8List key,
    Uint8List iv,
    Uint8List data, {
    required bool forEncryption,
  }) {
    final cipher = pc.PaddedBlockCipherImpl(
      pc.PKCS7Padding(),
      pc.CBCBlockCipher(pc.AESEngine()),
    );
    cipher.init(
      forEncryption,
      pc.PaddedBlockCipherParameters(
        pc.ParametersWithIV(pc.KeyParameter(key), iv),
        null,
      ),
    );
    return cipher.process(data);
  }

  Uint8List _randomIv() {
    final random = _customSecureRandom ?? math.Random.secure();
    final iv = Uint8List(16);
    for (var i = 0; i < iv.length; i++) {
      iv[i] = random.nextInt(256);
    }
    return iv;
  }

  bool _matchesXPacketProbe(Uint8List probe) {
    const marker = <int>[
      0x3C,
      0x3F,
      0x78,
      0x70,
      0x61,
      0x63,
      0x6B,
      0x65,
      0x74,
      0x20,
    ];
    if (probe.length < marker.length) {
      return false;
    }
    for (var i = 0; i < marker.length; i++) {
      if (probe[i] != marker[i]) {
        return false;
      }
    }
    return true;
  }
}

