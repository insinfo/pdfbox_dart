import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:pointycastle/export.dart' as pc;

import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_string.dart';
import '../pd_document.dart';
import 'access_permission.dart';
import 'decryption_material.dart';
import 'invalid_password_exception.dart';
import 'message_digests.dart';
import 'pd_crypt_filter_dictionary.dart';
import 'pd_encryption.dart';
import 'rc4_cipher.dart';
import 'security_handler.dart';
import 'standard_decryption_material.dart';
import 'standard_protection_policy.dart';
import 'sasl_prep.dart';
import 'protection_policy.dart';

/// Password based security handler mirroring Apache PDFBox' implementation.
class StandardSecurityHandler
    extends SecurityHandler<StandardProtectionPolicy> {
  static final Logger _log = Logger('StandardSecurityHandler');
  static const String filter = 'Standard';

  static const int _revision2 = 2;
  static const int _revision3 = 3;
  static const int _revision4 = 4;
  static const int _revision5 = 5;
  static const int _revision6 = 6;

  static const List<String> _hashes2B = <String>[
    'SHA-256',
    'SHA-384',
    'SHA-512'
  ];

  static final Uint8List _encryptPadding = Uint8List.fromList(<int>[
    0x28,
    0xBF,
    0x4E,
    0x5E,
    0x4E,
    0x75,
    0x8A,
    0x41,
    0x64,
    0x00,
    0x4E,
    0x56,
    0xFF,
    0xFA,
    0x01,
    0x08,
    0x2E,
    0x2E,
    0x00,
    0xB6,
    0xD0,
    0x68,
    0x3E,
    0x80,
    0x2F,
    0x0C,
    0xA9,
    0xFE,
    0x64,
    0x53,
    0x69,
    0x7A,
  ]);

  static final Uint8List _ffBytes =
      Uint8List.fromList(<int>[0xFF, 0xFF, 0xFF, 0xFF]);

  StandardSecurityHandler([StandardProtectionPolicy? policy])
      : super(protectionPolicy: policy);

  /// Computes the access permissions granted by the supplied [encryption]
  /// dictionary. When the dictionary omits the `/P` entry full owner
  /// permissions are returned.
  static AccessPermission permissionsFromEncryption(PDEncryption encryption) {
    final permissions = encryption.permissions;
    final accessPermission = permissions != null
        ? AccessPermission(permissions)
        : AccessPermission.ownerAccessPermission();
    accessPermission.setReadOnly();
    return accessPermission;
  }

  @override
  void prepareDocumentForEncryption(PDDocument document) {
    final policy = protectionPolicy;
    if (policy == null) {
      throw StateError('StandardSecurityHandler requires a protection policy');
    }

    var encryptionDictionary = document.encryption;
    encryptionDictionary ??= PDEncryption(COSDictionary());

    final version = computeVersionNumber();
    final revision = _computeRevisionNumber(version, policy.permissions);

    encryptionDictionary
      ..filter = filter
      ..version = version
      ..revision = revision
      ..length = keyLength;

    final permissionsValue = policy.permissions.permissionBytes;
    encryptionDictionary.permissions = permissionsValue;

    final ownerPassword = policy.ownerPassword;
    final userPassword = policy.userPassword;
    final effectiveOwnerPassword =
        ownerPassword.isEmpty ? userPassword : ownerPassword;
    final lengthInBytes = math.max(1, keyLength ~/ 8);

    if (revision == _revision6) {
      final preparedOwner = SaslPrep.saslPrepStored(effectiveOwnerPassword);
      final preparedUser = SaslPrep.saslPrepStored(userPassword);
      _prepareEncryptionDictRev6(
        preparedOwner,
        preparedUser,
        encryptionDictionary,
        permissionsValue,
      );
    } else {
      _prepareEncryptionDictRev234(
        effectiveOwnerPassword,
        userPassword,
        encryptionDictionary,
        permissionsValue,
        document,
        revision,
        lengthInBytes,
      );
    }

    final genericHandler = this as SecurityHandler<ProtectionPolicy>;
    encryptionDictionary.securityHandler = genericHandler;
    document.setSecurityHandler(genericHandler);
    document.setEncryptionDictionary(encryptionDictionary);
  }

  @override
  void prepareForDecryption(
    PDEncryption encryption,
    COSArray? documentIdArray,
    DecryptionMaterial decryptionMaterial,
  ) {
    if (decryptionMaterial is! StandardDecryptionMaterial) {
      throw ArgumentError(
        'Expected StandardDecryptionMaterial for StandardSecurityHandler',
      );
    }

    final revision = encryption.revision ?? _revision2;
    final version = encryption.version ?? 1;
    var lengthInBytes =
        version == 1 ? 5 : math.max(1, (encryption.length ?? keyLength) ~/ 8);
    keyLength = lengthInBytes * 8;
    decryptMetadata = encryption.encryptMetadata;
    isAES = false;

    if (version >= _revision4) {
      final cfDictionary = encryption.cfDictionary;
      if (cfDictionary != null) {
        final stdDict = cfDictionary.getCOSDictionary(COSName.stdCF);
        if (stdDict != null) {
          final stdFilter = PDCryptFilterDictionary(stdDict);
          final method = stdFilter.cryptFilterMethod;
          if (method == COSName.aesV2) {
            lengthInBytes = 16;
            keyLength = 128;
            isAES = true;
          } else if (method == COSName.aesV3) {
            lengthInBytes = 32;
            keyLength = 256;
            isAES = true;
          }
          decryptMetadata = stdFilter.encryptMetaData;

          final declaredLength = encryption.length;
          if (declaredLength != null && declaredLength ~/ 8 < lengthInBytes) {
            lengthInBytes = declaredLength ~/ 8;
            keyLength = declaredLength;
          }
        }
      }
    }

    if (revision >= _revision5) {
      final declaredLength = encryption.length ?? 256;
      lengthInBytes = math.max(1, declaredLength ~/ 8);
      keyLength = lengthInBytes * 8;
      if (lengthInBytes >= 16) {
        isAES = true;
      }
    }

    final ownerValue = encryption.ownerValue;
    final userValue = encryption.userValue;
    if (ownerValue == null || userValue == null) {
      throw StateError(
          'Encryption dictionary missing owner or user credentials');
    }

    final ownerKey = ownerValue.bytes;
    final userKey = userValue.bytes;
    final ownerEncryption = encryption.ownerEncryption?.bytes;
    final userEncryption = encryption.userEncryption?.bytes;

    final permissionsValue = encryption.permissions ??
        AccessPermission.ownerAccessPermission().permissionBytes;
    final documentId = _documentIdBytes(documentIdArray);

    final password = decryptionMaterial.password;
    final enteredPassword = _passwordBytesForRevision(password, revision);

    bool isOwnerPassword = false;
    Uint8List effectivePasswordBytes;

    if (_isOwnerPassword(
      enteredPassword,
      userKey,
      ownerKey,
      permissionsValue,
      documentId,
      revision,
      lengthInBytes,
      encryption.encryptMetadata,
    )) {
      final access = AccessPermission.ownerAccessPermission();
      setCurrentAccessPermission(access);
      if (revision >= _revision5) {
        effectivePasswordBytes = enteredPassword;
      } else {
        effectivePasswordBytes = _getUserPassword234(
          enteredPassword,
          ownerKey,
          revision,
          lengthInBytes,
        );
      }
      isOwnerPassword = true;
    } else if (_isUserPassword(
      enteredPassword,
      userKey,
      ownerKey,
      permissionsValue,
      documentId,
      revision,
      lengthInBytes,
      encryption.encryptMetadata,
    )) {
      final access = AccessPermission(permissionsValue);
      access.setReadOnly();
      setCurrentAccessPermission(access);
      effectivePasswordBytes = enteredPassword;
    } else {
      throw InvalidPasswordException(
          'Cannot decrypt PDF, the password is incorrect');
    }

    final encryptionKey = _computeFileEncryptionKey(
      effectivePasswordBytes,
      ownerKey,
      userKey,
      permissionsValue,
      documentId,
      revision,
      lengthInBytes,
      encryption.encryptMetadata,
      isOwnerPassword,
      ownerEncryptionKey: ownerEncryption,
      userEncryptionKey: userEncryption,
    );
    setEncryptionKey(encryptionKey);

    if (revision == _revision5 || revision == _revision6) {
      _validatePerms(encryption, permissionsValue, encryption.encryptMetadata);
    }
  }

  int _computeRevisionNumber(int version, AccessPermission permissions) {
    if (version < _revision2 && !permissions.hasAnyRevision3PermissionSet()) {
      return _revision2;
    }
    if (version == _revision5) {
      return _revision6;
    }
    if (version == _revision4) {
      return _revision4;
    }
    if (version == _revision2 ||
        version == _revision3 ||
        permissions.hasAnyRevision3PermissionSet()) {
      return _revision3;
    }
    return _revision4;
  }

  void _prepareEncryptionDictRev234(
    String ownerPassword,
    String userPassword,
    PDEncryption encryptionDictionary,
    int permissionInt,
    PDDocument document,
    int revision,
    int lengthInBytes,
  ) {
    final ownerBytes = _computeOwnerPassword(
      _latin1Bytes(ownerPassword),
      _latin1Bytes(userPassword),
      revision,
      lengthInBytes,
    );

    final idArray = _ensureDocumentId(document, ownerPassword, userPassword);
    final firstId = idArray.getObject(0);
    if (firstId is! COSString) {
      throw StateError('Document ID must be a COSString');
    }

    final userBytes = _computeUserPassword(
      _latin1Bytes(userPassword),
      ownerBytes,
      permissionInt,
      firstId.bytes,
      revision,
      lengthInBytes,
      true,
    );

    final encryptionKey = _computeEncryptedKeyRev234(
      _latin1Bytes(userPassword),
      ownerBytes,
      permissionInt,
      firstId.bytes,
      true,
      lengthInBytes,
      revision,
    );
    setEncryptionKey(encryptionKey);

    encryptionDictionary
      ..ownerValue = COSString.fromBytes(ownerBytes)
      ..userValue = COSString.fromBytes(userBytes);

    if (revision == _revision4 && isAES) {
      _prepareEncryptionDictAES(encryptionDictionary, COSName.aesV2);
    }
  }

  void _prepareEncryptionDictRev6(
    String ownerPassword,
    String userPassword,
    PDEncryption encryptionDictionary,
    int permissionInt,
  ) {
    final random = math.Random.secure();
    final zeroIv = Uint8List(16);

    final fileKey = _randomBytes(random, 32);
    setEncryptionKey(fileKey);

    final userPasswordBytes =
        _truncate127(Uint8List.fromList(utf8.encode(userPassword)));
    final userValidationSalt = _randomBytes(random, 8);
    final userKeySalt = _randomBytes(random, 8);

    final hashU = _computeHash2B(
      _concat(<Uint8List>[userPasswordBytes, userValidationSalt]),
      userPasswordBytes,
      null,
    );
    final u = _concat(<Uint8List>[hashU, userValidationSalt, userKeySalt]);

    final hashUE = _computeHash2B(
      _concat(<Uint8List>[userPasswordBytes, userKeySalt]),
      userPasswordBytes,
      null,
    );
    final ue = _aesCbc(
      hashUE,
      zeroIv,
      encryptionKeyOrThrow,
      forEncryption: true,
    );

    final ownerPasswordBytes =
        _truncate127(Uint8List.fromList(utf8.encode(ownerPassword)));
    final ownerValidationSalt = _randomBytes(random, 8);
    final ownerKeySalt = _randomBytes(random, 8);

    final hashO = _computeHash2B(
      _concat(<Uint8List>[ownerPasswordBytes, ownerValidationSalt, u]),
      ownerPasswordBytes,
      u,
    );
    final o = _concat(<Uint8List>[hashO, ownerValidationSalt, ownerKeySalt]);

    final hashOE = _computeHash2B(
      _concat(<Uint8List>[ownerPasswordBytes, ownerKeySalt, u]),
      ownerPasswordBytes,
      u,
    );
    final oe = _aesCbc(
      hashOE,
      zeroIv,
      encryptionKeyOrThrow,
      forEncryption: true,
    );

    final perms = Uint8List(16)
      ..setRange(0, 4, _intToBytesLE(permissionInt))
      ..[4] = 0xFF
      ..[5] = 0xFF
      ..[6] = 0xFF
      ..[7] = 0xFF
      ..[8] = 'T'.codeUnitAt(0)
      ..[9] = 'a'.codeUnitAt(0)
      ..[10] = 'd'.codeUnitAt(0)
      ..[11] = 'b'.codeUnitAt(0);
    perms.setRange(12, 16, _randomBytes(random, 4));

    final permsEncrypted = _aesCbc(
      encryptionKeyOrThrow,
      zeroIv,
      perms,
      forEncryption: true,
    );

    encryptionDictionary
      ..ownerValue = COSString.fromBytes(o)
      ..ownerEncryption = COSString.fromBytes(oe)
      ..userValue = COSString.fromBytes(u)
      ..userEncryption = COSString.fromBytes(ue)
      ..perms = COSString.fromBytes(permsEncrypted)
      ..encryptMetadata = true;

    _prepareEncryptionDictAES(encryptionDictionary, COSName.aesV3);
  }

  void _prepareEncryptionDictAES(
    PDEncryption encryptionDictionary,
    COSName aesName,
  ) {
    final cryptFilter = PDCryptFilterDictionary()
      ..setCryptFilterMethod(aesName)
      ..length = keyLength;
    final filters = COSDictionary()..setItem(COSName.stdCF, cryptFilter);
    encryptionDictionary
      ..cfDictionary = filters
      ..streamFilter = COSName.stdCF
      ..stringFilter = COSName.stdCF;
  }

  COSArray _ensureDocumentId(
    PDDocument document,
    String ownerPassword,
    String userPassword,
  ) {
    final trailer = document.cosDocument.trailer;
    var idArray = trailer.getCOSArray(COSName.id);
    if (idArray == null || idArray.length < 2) {
      final digest = MessageDigests.getMD5();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      digest.update(_bigIntToBytes(BigInt.from(timestamp)));
      digest.update(_latin1Bytes(ownerPassword));
      digest.update(_latin1Bytes(userPassword));
      digest.update(_latin1Bytes(document.cosDocument.toString()));
      digest.update(_latin1Bytes(toString()));
      final idBytes = digest.digest();
      final idString = COSString.fromBytes(idBytes);
      idArray = COSArray(<COSString>[idString, idString]);
      trailer[COSName.id] = idArray;
    }
    return idArray;
  }

  Uint8List _documentIdBytes(COSArray? documentIdArray) {
    if (documentIdArray == null || documentIdArray.isEmpty) {
      return Uint8List(0);
    }
    final first = documentIdArray.getObject(0);
    if (first is COSString) {
      return first.bytes;
    }
    return Uint8List(0);
  }

  Uint8List _passwordBytesForRevision(String password, int revision) {
    if (revision >= _revision5) {
      final normalized =
          revision == _revision6 ? _saslPrep(password) : password;
      return Uint8List.fromList(utf8.encode(normalized));
    }
    return Uint8List.fromList(latin1.encode(password));
  }

  Uint8List _computeOwnerPassword(
    Uint8List ownerPassword,
    Uint8List userPassword,
    int revision,
    int lengthInBytes,
  ) {
    if (revision == _revision2 && lengthInBytes != 5) {
      throw StateError('Revision 2 expects a 40-bit key (5 bytes)');
    }

    final rc4Key = _computeRC4Key(ownerPassword, revision, lengthInBytes);
    var encrypted = _rc4Process(rc4Key, _truncateOrPad(userPassword));

    if (revision == _revision3 || revision == _revision4) {
      for (var i = 1; i < 20; i++) {
        final iterationKey = _xorKey(rc4Key, i);
        encrypted = _rc4Process(iterationKey, encrypted);
      }
    }

    return encrypted;
  }

  Uint8List _computeUserPassword(
    Uint8List password,
    Uint8List owner,
    int permissions,
    Uint8List documentId,
    int revision,
    int lengthInBytes,
    bool encryptMetadata,
  ) {
    final encKey = _computeEncryptedKeyRev234(
      password,
      owner,
      permissions,
      documentId,
      encryptMetadata,
      lengthInBytes,
      revision,
    );

    if (revision == _revision2) {
      return _rc4Process(encKey, _encryptPadding);
    }

    if (revision == _revision3 || revision == _revision4) {
      final md = MessageDigests.getMD5();
      md.update(_encryptPadding);
      md.update(documentId);
      var digest = md.digest();
      var buffer = Uint8List.fromList(digest);
      for (var i = 0; i < 20; i++) {
        final iterationKey = _xorKey(encKey, i);
        buffer = _rc4Process(iterationKey, buffer);
      }
      final result = Uint8List(32)
        ..setRange(0, 16, buffer.sublist(0, 16))
        ..setRange(16, 32, _encryptPadding.sublist(0, 16));
      return result;
    }

    throw UnimplementedError(
        'Revision $revision user password computation not supported');
  }

  Uint8List _computeEncryptedKeyRev234(
    Uint8List password,
    Uint8List owner,
    int permissions,
    Uint8List documentId,
    bool encryptMetadata,
    int lengthInBytes,
    int revision,
  ) {
    final padded = _truncateOrPad(password);
    final md = MessageDigests.getMD5();
    md.update(padded);
    md.update(owner);
    md.update(_intToBytesLE(permissions));
    md.update(documentId);
    if (revision == _revision4 && !encryptMetadata) {
      md.update(_ffBytes);
    }
    var digest = md.digest();

    if (revision == _revision3 || revision == _revision4) {
      for (var i = 0; i < 50; i++) {
        final iteration = MessageDigests.getMD5();
        iteration.update(digest.sublist(0, lengthInBytes));
        digest = iteration.digest();
      }
    }

    return Uint8List.fromList(digest.sublist(0, lengthInBytes));
  }

  Uint8List _computeRC4Key(
    Uint8List ownerPassword,
    int revision,
    int lengthInBytes,
  ) {
    final md = MessageDigests.getMD5();
    md.update(_truncateOrPad(ownerPassword));
    var digest = md.digest();

    if (revision == _revision3 || revision == _revision4) {
      for (var i = 0; i < 50; i++) {
        final iteration = MessageDigests.getMD5();
        iteration.update(digest.sublist(0, lengthInBytes));
        digest = iteration.digest();
      }
    }

    return Uint8List.fromList(digest.sublist(0, lengthInBytes));
  }

  Uint8List _truncateOrPad(Uint8List password) {
    final output = Uint8List(_encryptPadding.length);
    final copyLength = math.min(password.length, output.length);
    output.setRange(0, copyLength, password);
    output.setRange(
        copyLength, output.length, _encryptPadding.sublist(copyLength));
    return output;
  }

  bool _isOwnerPassword(
    Uint8List ownerPassword,
    Uint8List user,
    Uint8List owner,
    int permissions,
    Uint8List documentId,
    int revision,
    int lengthInBytes,
    bool encryptMetadata,
  ) {
    if (revision == _revision5 || revision == _revision6) {
      return _isOwnerPassword56(ownerPassword, user, owner, revision);
    }
    final userPassword =
        _getUserPassword234(ownerPassword, owner, revision, lengthInBytes);
    return _isUserPassword234(
      userPassword,
      user,
      owner,
      permissions,
      documentId,
      revision,
      lengthInBytes,
      encryptMetadata,
    );
  }

  Uint8List _getUserPassword234(
    Uint8List ownerPassword,
    Uint8List owner,
    int revision,
    int lengthInBytes,
  ) {
    final rc4Key = _computeRC4Key(ownerPassword, revision, lengthInBytes);
    if (revision == _revision2) {
      return _rc4Process(rc4Key, owner);
    }
    if (revision == _revision3 || revision == _revision4) {
      var temp = Uint8List.fromList(owner);
      for (var i = 19; i >= 0; i--) {
        final iterationKey = _xorKey(rc4Key, i);
        temp = _rc4Process(iterationKey, temp);
      }
      return temp;
    }
    throw UnimplementedError(
        'Revision $revision owner password decoding not supported');
  }

  bool _isUserPassword(
    Uint8List password,
    Uint8List user,
    Uint8List owner,
    int permissions,
    Uint8List documentId,
    int revision,
    int lengthInBytes,
    bool encryptMetadata,
  ) {
    if (revision == _revision5 || revision == _revision6) {
      return _isUserPassword56(password, user, revision);
    }
    return _isUserPassword234(
      password,
      user,
      owner,
      permissions,
      documentId,
      revision,
      lengthInBytes,
      encryptMetadata,
    );
  }

  bool _isUserPassword234(
    Uint8List password,
    Uint8List user,
    Uint8List owner,
    int permissions,
    Uint8List documentId,
    int revision,
    int lengthInBytes,
    bool encryptMetadata,
  ) {
    final computed = _computeUserPassword(
      password,
      owner,
      permissions,
      documentId,
      revision,
      lengthInBytes,
      encryptMetadata,
    );
    if (revision == _revision2) {
      return _bytesEqual(user, computed);
    }
    return _bytesEqualPrefix(user, computed, 16);
  }

  Uint8List _computeFileEncryptionKey(
    Uint8List password,
    Uint8List owner,
    Uint8List user,
    int permissions,
    Uint8List documentId,
    int revision,
    int lengthInBytes,
    bool encryptMetadata,
    bool isOwnerPassword, {
    Uint8List? ownerEncryptionKey,
    Uint8List? userEncryptionKey,
  }) {
    if (revision == _revision2 ||
        revision == _revision3 ||
        revision == _revision4) {
      return _computeEncryptedKeyRev234(
        password,
        owner,
        permissions,
        documentId,
        encryptMetadata,
        lengthInBytes,
        revision,
      );
    }
    if (revision == _revision5 || revision == _revision6) {
      return _computeEncryptedKeyRev56(
        password,
        isOwnerPassword,
        owner,
        user,
        ownerEncryptionKey,
        userEncryptionKey,
        revision,
      );
    }
    throw UnimplementedError(
        'Revision $revision encryption key derivation not supported');
  }

  bool _isOwnerPassword56(
    Uint8List password,
    Uint8List user,
    Uint8List owner,
    int revision,
  ) {
    if (owner.length < 40) {
      throw StateError('Owner entry must contain at least 40 bytes');
    }
    final truncatedPassword = _truncate127(password);
    final oHash = owner.sublist(0, 32);
    final oValidationSalt = owner.sublist(32, 40);
    final expected = revision == _revision5
        ? _computeSHA256(truncatedPassword, oValidationSalt, user)
        : _computeHash2A(truncatedPassword, oValidationSalt, user);
    return _bytesEqual(oHash, expected);
  }

  bool _isUserPassword56(
    Uint8List password,
    Uint8List user,
    int revision,
  ) {
    if (user.length < 40) {
      throw StateError('User entry must contain at least 40 bytes');
    }
    final truncatedPassword = _truncate127(password);
    final uHash = user.sublist(0, 32);
    final uValidationSalt = user.sublist(32, 40);
    final expected = revision == _revision5
        ? _computeSHA256(truncatedPassword, uValidationSalt, null)
        : _computeHash2A(truncatedPassword, uValidationSalt, null);
    return _bytesEqual(uHash, expected);
  }

  Uint8List _computeEncryptedKeyRev56(
    Uint8List password,
    bool isOwnerPassword,
    Uint8List owner,
    Uint8List user,
    Uint8List? ownerEncryption,
    Uint8List? userEncryption,
    int revision,
  ) {
    final zeroIv = Uint8List(16);
    Uint8List hash;
    Uint8List encryptedKey;
    final truncatedPassword = _truncate127(password);
    if (isOwnerPassword) {
      if (owner.length < 48) {
        throw StateError('Owner entry must contain at least 48 bytes');
      }
      if (ownerEncryption == null) {
        throw StateError('Encryption dictionary missing /OE entry');
      }
      final salt = owner.sublist(40, 48);
      hash = revision == _revision5
          ? _computeSHA256(truncatedPassword, salt, user)
          : _computeHash2A(truncatedPassword, salt, user);
      encryptedKey = ownerEncryption;
    } else {
      if (user.length < 48) {
        throw StateError('User entry must contain at least 48 bytes');
      }
      if (userEncryption == null) {
        throw StateError('Encryption dictionary missing /UE entry');
      }
      final salt = user.sublist(40, 48);
      hash = revision == _revision5
          ? _computeSHA256(truncatedPassword, salt, null)
          : _computeHash2A(truncatedPassword, salt, null);
      encryptedKey = userEncryption;
    }
    return _aesCbc(hash, zeroIv, encryptedKey, forEncryption: false);
  }

  Uint8List _computeSHA256(
    Uint8List input,
    Uint8List salt,
    Uint8List? userKey,
  ) {
    final digest = MessageDigests.getSHA256();
    digest.update(input);
    digest.update(salt);
    final adjusted = _adjustUserKey(userKey);
    if (adjusted.isNotEmpty) {
      digest.update(adjusted);
    }
    return digest.digest();
  }

  Uint8List _computeHash2A(
    Uint8List password,
    Uint8List salt,
    Uint8List? userKey,
  ) {
    final truncatedPassword = _truncate127(password);
    final adjusted = _adjustUserKey(userKey);
    final input = _concat(<Uint8List>[truncatedPassword, salt, adjusted]);
    return _computeHash2B(
        input, truncatedPassword, adjusted.isEmpty ? null : adjusted);
  }

  Uint8List _computeHash2B(
    Uint8List input,
    Uint8List password,
    Uint8List? userKey,
  ) {
    var k = _digestMany('SHA-256', <Uint8List>[input]);
    Uint8List e = Uint8List(0);
    var hasUserKey = false;
    Uint8List? userKeySlice;
    if (userKey != null && userKey.length >= 48) {
      hasUserKey = true;
      userKeySlice = userKey.sublist(0, 48);
    }
    for (var round = 0;
        round < 64 || (e.isNotEmpty && (e[e.length - 1] & 0xff) > round - 32);
        round++) {
      final chunkLength = password.length + k.length + (hasUserKey ? 48 : 0);
      final buffer = Uint8List(64 * chunkLength);
      var offset = 0;
      for (var i = 0; i < 64; i++) {
        buffer.setRange(offset, offset + password.length, password);
        offset += password.length;
        buffer.setRange(offset, offset + k.length, k);
        offset += k.length;
        if (hasUserKey && userKeySlice != null) {
          buffer.setRange(offset, offset + 48, userKeySlice);
          offset += 48;
        }
      }

      final kFirst = k.sublist(0, 16);
      final kSecond = k.sublist(16, 32);
      e = _aesCbc(kFirst, kSecond, buffer, forEncryption: true);

      final eFirst = e.sublist(0, 16);
      var value = BigInt.zero;
      for (final byte in eFirst) {
        value = (value << 8) | BigInt.from(byte & 0xff);
      }
      final remainder = value.remainder(BigInt.from(3)).toInt();
      final nextHash = _hashes2B[remainder];
      k = _digestMany(nextHash, <Uint8List>[e]);
    }

    if (k.length > 32) {
      return Uint8List.fromList(k.sublist(0, 32));
    }
    return k;
  }

  Uint8List _adjustUserKey(Uint8List? userKey) {
    if (userKey == null) {
      return Uint8List(0);
    }
    if (userKey.length < 48) {
      throw StateError('User entry must contain at least 48 bytes');
    }
    if (userKey.length == 48) {
      return Uint8List.fromList(userKey);
    }
    return Uint8List.fromList(userKey.sublist(0, 48));
  }

  Uint8List _truncate127(Uint8List input) {
    if (input.length <= 127) {
      return Uint8List.fromList(input);
    }
    return Uint8List.fromList(input.sublist(0, 127));
  }

  Uint8List _concat(List<Uint8List> parts) {
    final length = parts.fold<int>(0, (sum, part) => sum + part.length);
    final result = Uint8List(length);
    var offset = 0;
    for (final part in parts) {
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return result;
  }

  Uint8List _aesCbc(
    Uint8List key,
    Uint8List iv,
    Uint8List data, {
    required bool forEncryption,
  }) {
    final cipher = pc.CBCBlockCipher(pc.AESEngine())
      ..init(forEncryption, pc.ParametersWithIV(pc.KeyParameter(key), iv));
    final blockSize = cipher.blockSize;
    final output = Uint8List(data.length);
    for (var offset = 0; offset < data.length; offset += blockSize) {
      cipher.processBlock(data, offset, output, offset);
    }
    return output;
  }

  Uint8List _aesEcbDecrypt(Uint8List key, Uint8List data) {
    final engine = pc.AESEngine()..init(false, pc.KeyParameter(key));
    final blockSize = engine.blockSize;
    final output = Uint8List(data.length);
    for (var offset = 0; offset < data.length; offset += blockSize) {
      engine.processBlock(data, offset, output, offset);
    }
    return output;
  }

  Uint8List _digestMany(String algorithm, List<Uint8List> parts) {
    final digest = pc.Digest(algorithm);
    for (final part in parts) {
      digest.update(part, 0, part.length);
    }
    final output = Uint8List(digest.digestSize);
    digest.doFinal(output, 0);
    return output;
  }

  String _saslPrep(String value) {
    return SaslPrep.saslPrepStored(value);
  }

  void _validatePerms(
    PDEncryption encryption,
    int permissions,
    bool encryptMetadata,
  ) {
    final permsString = encryption.perms;
    if (permsString == null) {
      _log.warning(
          'Encryption dictionary missing /Perms entry for revision 5/6');
      return;
    }
    final perms = permsString.bytes;
    if (perms.length != 16) {
      _log.warning(
          'Expected 16-byte /Perms entry but found ${perms.length} bytes');
      return;
    }
    try {
      final decrypted = _aesEcbDecrypt(encryptionKeyOrThrow, perms);
      final permsP = (decrypted[0] & 0xff) |
          ((decrypted[1] & 0xff) << 8) |
          ((decrypted[2] & 0xff) << 16) |
          ((decrypted[3] & 0xff) << 24);
      if (permsP != permissions) {
        _log.warning(
            'Permissions mismatch between /Perms (${permsP.toRadixString(16)}) and /P (${permissions.toRadixString(16)})');
      }
      final metadataFlag = decrypted[8];
      final expectedFlag =
          encryptMetadata ? 'T'.codeUnitAt(0) : 'F'.codeUnitAt(0);
      if (metadataFlag != expectedFlag) {
        _log.warning('Perms metadata flag does not match EncryptMetadata');
      }
      if (decrypted[9] != 'a'.codeUnitAt(0) ||
          decrypted[10] != 'd'.codeUnitAt(0) ||
          decrypted[11] != 'b'.codeUnitAt(0)) {
        _log.warning('Perms constant marker is invalid');
      }
    } catch (e) {
      _log.warning('Failed to validate permissions: $e');
    }
  }

  Uint8List _rc4Process(Uint8List key, Uint8List data) {
    final cipher = RC4Cipher();
    cipher.setKey(key);
    return cipher.process(data);
  }

  Uint8List _xorKey(Uint8List key, int value) {
    final result = Uint8List(key.length);
    for (var i = 0; i < key.length; i++) {
      result[i] = key[i] ^ value;
    }
    return result;
  }

  Uint8List _latin1Bytes(String value) =>
      Uint8List.fromList(latin1.encode(value));

  Uint8List _intToBytesLE(int value) {
    final buffer = Uint8List(4);
    buffer[0] = value & 0xFF;
    buffer[1] = (value >> 8) & 0xFF;
    buffer[2] = (value >> 16) & 0xFF;
    buffer[3] = (value >> 24) & 0xFF;
    return buffer;
  }

  Uint8List _randomBytes(math.Random random, int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  Uint8List _bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) {
      return Uint8List.fromList(<int>[0]);
    }
    final bytes = <int>[];
    var current = value;
    while (current > BigInt.zero) {
      bytes.add((current & BigInt.from(0xFF)).toInt());
      current = current >> 8;
    }
    return Uint8List.fromList(bytes.reversed.toList());
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  bool _bytesEqualPrefix(Uint8List a, Uint8List b, int length) {
    if (a.length < length || b.length < length) {
      return false;
    }
    for (var i = 0; i < length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
