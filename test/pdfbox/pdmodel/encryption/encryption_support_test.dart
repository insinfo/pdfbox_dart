import 'dart:typed_data';

import 'package:pdfbox_dart/src/dependencies/x509_plus/x509.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/access_permission.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/invalid_password_exception.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/message_digests.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/pd_crypt_filter_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/public_key_protection_policy.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/public_key_recipient.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/rc4_cipher.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/standard_decryption_material.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/standard_protection_policy.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/standard_security_handler.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/pd_encryption.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:test/test.dart';

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
