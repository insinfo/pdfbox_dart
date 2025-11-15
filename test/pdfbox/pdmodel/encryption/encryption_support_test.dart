import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pdfbox_dart/src/dependencies/x509_plus/x509.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/access_permission.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/invalid_password_exception.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/message_digests.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/pd_crypt_filter_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/pd_encryption.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/public_key_protection_policy.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/public_key_recipient.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/rc4_cipher.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/security_handler_factory.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/standard_decryption_material.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/standard_protection_policy.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/standard_security_handler.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/sasl_prep.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:test/test.dart';
import 'package:pointycastle/export.dart' as pc;

X509Certificate _buildDummyCertificate() {
  final algorithm = AlgorithmIdentifier(
    const ObjectIdentifier(<int>[1, 2, 840, 113549, 1, 1, 1]),
    null,
  );
  return X509Certificate(
    const TbsCertificate(),
    algorithm,
    const <int>[],
  );
}

void main() {
  group('ProtectionPolicy', () {
    test('enforces allowed key lengths', () {
      final policy = StandardProtectionPolicy(
        'owner',
        'user',
        AccessPermission(),
      );
      policy.setEncryptionKeyLength(128);
      expect(policy.encryptionKeyLength, 128);
      expect(policy.getEncryptionKeyLength(), 128);
      expect(policy.isPreferAES(), isFalse);

      policy.setPreferAES(true);
      expect(policy.preferAes, isTrue);

      expect(() => policy.setEncryptionKeyLength(41), throwsArgumentError);
    });

    test('standard policy getters reflect setters', () {
      final permission = AccessPermission()
        ..setCanModify(false)
        ..setCanExtractContent(false);
      final policy = StandardProtectionPolicy('owner', 'user', permission);

      expect(policy.permissions, same(permission));
      expect(policy.getPermissions(), same(permission));

      policy.ownerPassword = 'o2';
      policy.userPassword = 'u2';

      expect(policy.getOwnerPassword(), 'o2');
      expect(policy.getUserPassword(), 'u2');

      final newPermission = AccessPermission();
      policy.setPermissions(newPermission);
      expect(policy.permissions, same(newPermission));
    });

    test('access permission flags detect revision 3 bits', () {
      final permission = AccessPermission()
        ..setCanFillInForm(true)
        ..setCanExtractForAccessibility(false)
        ..setCanAssembleDocument(false)
        ..setCanPrintFaithful(false);
      expect(permission.hasAnyRevision3PermissionSet(), isTrue);

      permission
        ..setCanFillInForm(false)
        ..setCanExtractForAccessibility(false)
        ..setCanAssembleDocument(false)
        ..setCanPrintFaithful(false);
      expect(permission.hasAnyRevision3PermissionSet(), isFalse);
    });
  });

  group('Public key policy', () {
    test('manages recipients and certificates', () {
      final policy = PublicKeyProtectionPolicy();
      final recipient = PublicKeyRecipient()
        ..permission = AccessPermission()
        ..certificate = _buildDummyCertificate();

      policy.addRecipient(recipient);
      expect(policy.numberOfRecipients, 1);
      expect(policy.recipients.single, same(recipient));
      expect(policy.getRecipientsIterator().moveNext(), isTrue);

      final removed = policy.removeRecipient(recipient);
      expect(removed, isTrue);
      expect(policy.numberOfRecipients, 0);

      final certificate = _buildDummyCertificate();
      policy.decryptionCertificate = certificate;
      expect(policy.getDecryptionCertificate(), same(certificate));
    });

    test('recipient accessors mirror Java API', () {
      final recipient = PublicKeyRecipient();
      final certificate = _buildDummyCertificate();
      final permission = AccessPermission();

      recipient.setX509(certificate);
      recipient.setPermission(permission);

      expect(recipient.getX509(), same(certificate));
      expect(recipient.getPermission(), same(permission));
    });
  });

  group('MessageDigest', () {
    test('computes expected hashes', () {
      final data = Uint8List.fromList('hello world'.codeUnits);

      final md5 = MessageDigests.getMD5();
      md5.update(data);
      expect(_toHex(md5.digest()), '5eb63bbbe01eeed093cb22bb8f5acdc3');

      final sha1 = MessageDigests.getSHA1();
      sha1.update(data);
      expect(_toHex(sha1.digest()), '2aae6c35c94fcfb415dbe95f408b9ce91ee846ed');

      final sha256 = MessageDigests.getSHA256();
      sha256.update(data);
      expect(_toHex(sha256.digest()),
          'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9');

      // digest() is idempotent once closed
      expect(_toHex(sha256.digest()),
          'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9');
    });
  });

  group('RC4Cipher', () {
    test('matches known test vector', () {
      final cipher = RC4Cipher();
      final key = 'Key'.codeUnits;
      cipher.setKey(key);

      final plaintext = 'Plaintext'.codeUnits;
      final ciphertext = cipher.process(plaintext);
      expect(_toHex(ciphertext), 'bbf316e8d940af0ad3');

      // Decrypt by reinitialising state and processing ciphertext
      cipher.setKey(key);
      final decrypted = cipher.process(ciphertext);
      expect(String.fromCharCodes(decrypted), 'Plaintext');
    });
  });

  group('PDCryptFilterDictionary', () {
    test('manages length and metadata flag', () {
      final dictionary = PDCryptFilterDictionary();
      expect(dictionary.length, 40);
      expect(dictionary.encryptMetaData, isTrue);

      dictionary.length = 16;
      expect(dictionary.length, 16);

      dictionary.setCryptFilterMethod(null);
      expect(dictionary.cryptFilterMethod, isNull);

      dictionary.setCryptFilterMethod(COSName.aesV2);
      expect(dictionary.cryptFilterMethod, COSName.aesV2);

      dictionary.encryptMetaData = false;
      expect(dictionary.encryptMetaData, isFalse);
    });
  });

  group('SecurityHandler', () {
    test('policy configuration toggles AES and key length', () {
      final policy = StandardProtectionPolicy(
        'owner',
        'user',
        AccessPermission(),
      )
        ..setEncryptionKeyLength(128)
        ..setPreferAES(true);
      final handler = StandardSecurityHandler(policy);
      expect(handler.keyLength, 128);
      expect(handler.isAES, isTrue);
    });

    test('deriveObjectKey matches specification', () {
      final handler = StandardSecurityHandler();
      final baseKey = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      handler.setEncryptionKey(baseKey);
      final derivedKey = handler.deriveObjectKey(5, 0);

      final expectedSeed = Uint8List.fromList(<int>[
        ...baseKey,
        5 & 0xff,
        (5 >> 8) & 0xff,
        (5 >> 16) & 0xff,
        0,
        0,
      ]);
      final digest = crypto.md5.convert(expectedSeed).bytes;
      final expected = digest.sublist(0, math.min(baseKey.length + 5, 16));
      expect(derivedKey, orderedEquals(expected));
    });

    test('applyRC4 round-trips data', () {
      final handler = StandardSecurityHandler();
      final baseKey = Uint8List.fromList(<int>[9, 8, 7, 6, 5]);
      handler.setEncryptionKey(baseKey);
      final plaintext = Uint8List.fromList('Secret'.codeUnits);
      final ciphertext = handler.applyRC4ToBytes(plaintext, 1, 0);

      handler.setEncryptionKey(baseKey);
      final decrypted = handler.applyRC4ToBytes(ciphertext, 1, 0);
      expect(decrypted, orderedEquals(plaintext));
    });

    test('factory resolves standard handlers by filter and policy', () {
      final factory = SecurityHandlerFactory.instance;
      final filterHandler =
          factory.newSecurityHandlerForFilter(StandardSecurityHandler.filter);
      expect(filterHandler, isA<StandardSecurityHandler>());

      final policy = StandardProtectionPolicy(
        'owner',
        'user',
        AccessPermission(),
      );
      final policyHandler = factory.newSecurityHandlerForPolicy(policy);
      expect(policyHandler, isA<StandardSecurityHandler>());
    });

    test('prepareDocumentForEncryption round-trips with prepareForDecryption',
        () {
      final document = PDDocument();
      final permissions = AccessPermission()
        ..setCanModify(false)
        ..setCanExtractContent(false);
      final policy = StandardProtectionPolicy('owner', 'user', permissions)
        ..setEncryptionKeyLength(40);

      final encryptingHandler = StandardSecurityHandler(policy);
      encryptingHandler.prepareDocumentForEncryption(document);

      final encryption = document.encryption;
      expect(encryption, isNotNull);
      final documentId = document.cosDocument.trailer.getCOSArray(COSName.id);
      expect(documentId, isNotNull);

      final decryptingHandler = StandardSecurityHandler();
      decryptingHandler.prepareForDecryption(
        encryption!,
        documentId,
        const StandardDecryptionMaterial('user'),
      );

      expect(decryptingHandler.encryptionKey, isNotNull);
      expect(
        decryptingHandler.encryptionKey,
        orderedEquals(encryptingHandler.encryptionKey!),
      );

      final granted = decryptingHandler.currentAccessPermission;
      expect(granted, isNotNull);
      expect(granted!.permissionBytes, permissions.permissionBytes);
    });

    test('prepareDocumentForEncryption emits revision 6 dictionary', () {
      final document = PDDocument();
      final permissions = AccessPermission()
        ..setCanModify(false)
        ..setCanExtractContent(false);
      final policy =
          StandardProtectionPolicy('owner\u00A0pass', '\u212Buser', permissions)
            ..setEncryptionKeyLength(256);

      final handler = StandardSecurityHandler(policy);
      handler.prepareDocumentForEncryption(document);

      final encryption = document.encryption;
      expect(encryption, isNotNull);
      expect(encryption!.revision, 6);
      expect(encryption.streamFilter, equals(COSName.stdCF));
      expect(encryption.stringFilter, equals(COSName.stdCF));
      expect(encryption.cfDictionary, isNotNull);

      final fileKey = handler.encryptionKey;
      expect(fileKey, isNotNull);
      expect(fileKey!.length, 32);

      final owner = encryption.ownerValue?.bytes;
      final user = encryption.userValue?.bytes;
      final ownerEncryption = encryption.ownerEncryption?.bytes;
      final userEncryption = encryption.userEncryption?.bytes;
      final perms = encryption.perms?.bytes;

      expect(owner, isNotNull);
      expect(user, isNotNull);
      expect(ownerEncryption, isNotNull);
      expect(userEncryption, isNotNull);
      expect(perms, isNotNull);
      expect(owner!.length, 48);
      expect(user!.length, 48);
      expect(ownerEncryption!.length, 32);
      expect(userEncryption!.length, 32);
      expect(perms!.length, 16);

      final expectedKey = _referenceFileKey(
        password: '\u212Buser',
        isOwnerPassword: false,
        owner: owner,
        user: user,
        ownerEncryption: ownerEncryption,
        userEncryption: userEncryption,
        revision: 6,
      );
      expect(fileKey, orderedEquals(expectedKey));

      final permsPlain = _aesEcbDecrypt(expectedKey, perms);
      expect(permsPlain.length, 16);
      expect(
        _littleEndianToInt(permsPlain.sublist(0, 4)),
        _asSigned32(permissions.permissionBytes),
      );
      expect(permsPlain[4], 0xFF);
      expect(permsPlain[5], 0xFF);
      expect(permsPlain[6], 0xFF);
      expect(permsPlain[7], 0xFF);
      expect(permsPlain[8], 'T'.codeUnitAt(0));
      expect(permsPlain[9], 'a'.codeUnitAt(0));
      expect(permsPlain[10], 'd'.codeUnitAt(0));
      expect(permsPlain[11], 'b'.codeUnitAt(0));

      expect(encryption.encryptMetadata, isTrue);
    });

    test('prepareForDecryption unlocks revision 6 sample PDFBox dictionary',
        () {
      final encryption = _buildPasswordSample256Encryption();
      final handler = StandardSecurityHandler();

      handler.prepareForDecryption(
        encryption,
        null,
        const StandardDecryptionMaterial('user'),
      );

      final key = handler.encryptionKey;
      expect(key, isNotNull);
      final expectedUserKey = _referenceFileKey(
        password: 'user',
        isOwnerPassword: false,
        owner: _passwordSample256Owner,
        user: _passwordSample256User,
        ownerEncryption: _passwordSample256OE,
        userEncryption: _passwordSample256UE,
        revision: 6,
      );
      expect(key, orderedEquals(expectedUserKey));

      final permsPlain =
          _aesEcbDecrypt(expectedUserKey, _passwordSample256Perms);
      expect(permsPlain.length, 16);
      expect(_littleEndianToInt(permsPlain.sublist(0, 4)), -3616);
      expect(String.fromCharCodes(permsPlain.sublist(8, 11)), 'Tad');
      expect(handler.currentAccessPermission?.isOwnerPermission, isFalse);
      expect(handler.isAES, isTrue);

      final ownerHandler = StandardSecurityHandler();
      ownerHandler.prepareForDecryption(
        _buildPasswordSample256Encryption(),
        null,
        const StandardDecryptionMaterial('owner'),
      );
      final ownerKey = ownerHandler.encryptionKey;
      final expectedOwnerKey = _referenceFileKey(
        password: 'owner',
        isOwnerPassword: true,
        owner: _passwordSample256Owner,
        user: _passwordSample256User,
        ownerEncryption: _passwordSample256OE,
        userEncryption: _passwordSample256UE,
        revision: 6,
      );
      expect(ownerKey, orderedEquals(expectedOwnerKey));
      expect(ownerHandler.currentAccessPermission?.isOwnerPermission, isTrue);

      final wrongHandler = StandardSecurityHandler();
      expect(
        () => wrongHandler.prepareForDecryption(
          _buildPasswordSample256Encryption(),
          null,
          const StandardDecryptionMaterial('wrong'),
        ),
        throwsA(isA<InvalidPasswordException>()),
      );
    });
  });

  group('Credential helpers', () {
    test('standard decryption material stores password', () {
      const material = StandardDecryptionMaterial('secret');
      expect(material.password, 'secret');
    });

    test('invalid password exception surfaces message', () {
      final error = InvalidPasswordException('bad password');
      expect(error.message, 'bad password');
      expect(error.toString(), contains('bad password'));
    });

    test(
        'standard security handler derives permissions from encryption dictionary',
        () {
      final encryption = PDEncryption(COSDictionary())
        ..permissions = AccessPermission().permissionBytes;
      final permission =
          StandardSecurityHandler.permissionsFromEncryption(encryption);
      expect(permission.isOwnerPermission, isTrue);
    });
  });
}

String _toHex(List<int> input) =>
    input.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

PDEncryption _buildPasswordSample256Encryption() {
  final encryption = PDEncryption(COSDictionary())
    ..filter = StandardSecurityHandler.filter
    ..version = 5
    ..revision = 6
    ..length = 256
    ..permissions = -3616
    ..encryptMetadata = true
    ..ownerValue = COSString.fromBytes(_passwordSample256Owner)
    ..userValue = COSString.fromBytes(_passwordSample256User)
    ..ownerEncryption = COSString.fromBytes(_passwordSample256OE)
    ..userEncryption = COSString.fromBytes(_passwordSample256UE)
    ..perms = COSString.fromBytes(_passwordSample256Perms);

  final cryptFilter = PDCryptFilterDictionary()
    ..setCryptFilterMethod(COSName.aesV3)
    ..length = 256;
  final filters = COSDictionary()
    ..setItem(COSName.stdCF, cryptFilter.cosObject);
  encryption
    ..cfDictionary = filters
    ..streamFilter = COSName.stdCF
    ..stringFilter = COSName.stdCF;

  return encryption;
}

final Uint8List _passwordSample256Owner =
    _hexToBytes(_passwordSample256OwnerHex);
final Uint8List _passwordSample256User = _hexToBytes(_passwordSample256UserHex);
final Uint8List _passwordSample256OE = _hexToBytes(_passwordSample256OEHex);
final Uint8List _passwordSample256UE = _hexToBytes(_passwordSample256UEHex);
final Uint8List _passwordSample256Perms =
    _hexToBytes(_passwordSample256PermsHex);

Uint8List _referenceFileKey({
  required String password,
  required bool isOwnerPassword,
  required Uint8List owner,
  required Uint8List user,
  required Uint8List ownerEncryption,
  required Uint8List userEncryption,
  required int revision,
}) {
  final prepared = revision == 6 ? SaslPrep.saslPrepStored(password) : password;
  final encoded =
      revision >= 5 ? utf8.encode(prepared) : latin1.encode(prepared);
  final passwordBytes = Uint8List.fromList(encoded);
  final truncated = _truncate127(passwordBytes);
  final zeroIv = Uint8List(16);
  if (isOwnerPassword) {
    final salt = owner.sublist(40, 48);
    final hash = revision == 5
        ? _computeSha256(truncated, salt, user)
        : _computeHash2A(truncated, salt, user);
    return _aesCbcDecrypt(hash, zeroIv, ownerEncryption);
  }
  final salt = user.sublist(40, 48);
  final hash = revision == 5
      ? _computeSha256(truncated, salt, null)
      : _computeHash2A(truncated, salt, null);
  return _aesCbcDecrypt(hash, zeroIv, userEncryption);
}

Uint8List _computeSha256(
  Uint8List input,
  Uint8List salt,
  Uint8List? userKey,
) {
  final digest = pc.SHA256Digest()
    ..update(input, 0, input.length)
    ..update(salt, 0, salt.length);
  final adjusted = _adjustUserKey(userKey);
  if (adjusted.isNotEmpty) {
    digest.update(adjusted, 0, adjusted.length);
  }
  final output = Uint8List(digest.digestSize);
  digest.doFinal(output, 0);
  return output;
}

Uint8List _computeHash2A(
  Uint8List password,
  Uint8List salt,
  Uint8List? userKey,
) {
  final truncated = _truncate127(password);
  final adjusted = _adjustUserKey(userKey);
  final input = _concat(<Uint8List>[truncated, salt, adjusted]);
  return _computeHash2B(input, truncated, adjusted.isEmpty ? null : adjusted);
}

Uint8List _computeHash2B(
  Uint8List input,
  Uint8List password,
  Uint8List? userKey,
) {
  var digest = pc.Digest('SHA-256');
  digest.update(input, 0, input.length);
  var k = Uint8List(digest.digestSize);
  digest.doFinal(k, 0);

  Uint8List e = Uint8List(0);
  final hasUserKey = userKey != null && userKey.length >= 48;
  final userKeySlice =
      (userKey != null && userKey.length >= 48) ? userKey.sublist(0, 48) : null;

  for (var round = 0;
      round < 64 || (e.isNotEmpty && ((e[e.length - 1] & 0xff) > round - 32));
      round++) {
    final chunkLength = password.length + k.length + (hasUserKey ? 48 : 0);
    final buffer = Uint8List(64 * chunkLength);
    var offset = 0;
    for (var i = 0; i < 64; i++) {
      buffer.setRange(offset, offset + password.length, password);
      offset += password.length;
      buffer.setRange(offset, offset + k.length, k);
      offset += k.length;
      if (userKeySlice != null) {
        buffer.setRange(offset, offset + 48, userKeySlice);
        offset += 48;
      }
    }

    final cipher = pc.CBCBlockCipher(pc.AESEngine())
      ..init(
        true,
        pc.ParametersWithIV(
          pc.KeyParameter(k.sublist(0, 16)),
          k.sublist(16, 32),
        ),
      );
    e = Uint8List(buffer.length);
    for (var blockOffset = 0;
        blockOffset < buffer.length;
        blockOffset += cipher.blockSize) {
      cipher.processBlock(buffer, blockOffset, e, blockOffset);
    }

    final firstBlock = e.sublist(0, 16);
    var value = BigInt.zero;
    for (final byte in firstBlock) {
      value = (value << 8) | BigInt.from(byte & 0xff);
    }
    final remainder = value.remainder(BigInt.from(3)).toInt();
    final nextHash = _hashes2B[remainder];
    digest = pc.Digest(nextHash)..update(e, 0, e.length);
    k = Uint8List(digest.digestSize);
    digest.doFinal(k, 0);
  }

  if (k.length > 32) {
    return Uint8List.fromList(k.sublist(0, 32));
  }
  return k;
}

Uint8List _aesCbcDecrypt(Uint8List key, Uint8List iv, Uint8List data) {
  final cipher = pc.CBCBlockCipher(pc.AESEngine())
    ..init(false, pc.ParametersWithIV(pc.KeyParameter(key), iv));
  final output = Uint8List(data.length);
  for (var offset = 0; offset < data.length; offset += cipher.blockSize) {
    cipher.processBlock(data, offset, output, offset);
  }
  return output;
}

Uint8List _aesEcbDecrypt(Uint8List key, Uint8List data) {
  final engine = pc.AESEngine()..init(false, pc.KeyParameter(key));
  final output = Uint8List(data.length);
  for (var offset = 0; offset < data.length; offset += engine.blockSize) {
    engine.processBlock(data, offset, output, offset);
  }
  return output;
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

int _littleEndianToInt(List<int> bytes) {
  var result = 0;
  for (var i = 0; i < bytes.length; i++) {
    result |= (bytes[i] & 0xff) << (8 * i);
  }
  return _asSigned32(result);
}

int _asSigned32(int value) {
  if (value & 0x80000000 != 0) {
    return value | ~0xffffffff;
  }
  return value;
}

Uint8List _hexToBytes(String hex) {
  final cleaned = hex.replaceAll(RegExp(r'\s+'), '');
  final result = Uint8List(cleaned.length ~/ 2);
  for (var i = 0; i < cleaned.length; i += 2) {
    result[i ~/ 2] = int.parse(cleaned.substring(i, i + 2), radix: 16);
  }
  return result;
}

const List<String> _hashes2B = <String>['SHA-256', 'SHA-384', 'SHA-512'];

const String _passwordSample256OwnerHex =
    '28230e985d7e930fa1542cd07b284e3c3daaa28f616aae96e947dd0a44065b697b2b69832409758871eacda56aa6ab4800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';

const String _passwordSample256UserHex =
    'bb9a614358761bd3e4f10ef424a2fa42e7ad9d9e62a97e82e7c69926ff61c630ab27af1da697b2b9550e2c1131a3886e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';

const String _passwordSample256OEHex =
    '599b93347833d9e4d464c93e01a88bb0914d5c87935b03d0ddc8dbbfd258af23';

const String _passwordSample256UEHex =
    'a1cb3e2397771d525d6e1814a2140983b865465ed3977ab2288667d42ed9b519';

const String _passwordSample256PermsHex = '385e3d765015923322c76d74ef59a531';
