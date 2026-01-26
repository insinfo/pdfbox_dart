import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/pdf_signature_validation.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/security/pdf_cms_signer.dart';
import 'package:test/test.dart';

void main() {
  group('PdfCmsSigner', () {
    test('signDetachedSha256RsaFromCertificate produces a valid CMS signature',
      () {
      if (!_hasOpenSsl()) return;

      final Directory testDir = Directory.systemTemp.createTempSync('cms_pem_');
      try {
        _runCmdSync('openssl', <String>[
          'req',
          '-x509',
          '-newkey',
          'rsa:2048',
          '-keyout',
          '${testDir.path}/user_key.pem',
          '-out',
          '${testDir.path}/user_cert.pem',
          '-days',
          '365',
          '-nodes',
          '-subj',
          '/CN=John Doe',
          '-addext',
          'keyUsage=digitalSignature'
        ]);

        final String privateKeyPem =
            File('${testDir.path}/user_key.pem').readAsStringSync();
        final String certificatePem =
            File('${testDir.path}/user_cert.pem').readAsStringSync();

        final Uint8List content = Uint8List.fromList(
          utf8.encode('cms-detached-test-content'),
        );
        final Uint8List digest =
            Uint8List.fromList(sha256.convert(content).bytes);

        final Uint8List cmsDer = PdfCmsSigner.signDetachedSha256RsaFromPem(
          contentDigest: digest,
          privateKeyPem: privateKeyPem,
          certificatePem: certificatePem,
          chainPem: const <String>[],
        );

        expect(cmsDer, isNotEmpty);

        final PdfSignatureValidation validator =
            PdfSignatureValidation();
        final result = validator.validateCmsSignedData(cmsDer);
        expect(result.cmsSignatureValid, isTrue);
        expect(result.certsPem, isNotEmpty);
      } finally {
        if (testDir.existsSync()) {
          testDir.deleteSync(recursive: true);
        }
      }
    });

    test('signDetachedSha256EcdsaFromPem produces a valid CMS signature', () {
      if (!_hasOpenSsl()) return;

      final Directory testDir = Directory.systemTemp.createTempSync('cms_ec_');
      try {
        _runCmdSync('openssl', <String>[
          'ecparam',
          '-name',
          'prime256v1',
          '-genkey',
          '-noout',
          '-out',
          '${testDir.path}/ec_key.pem',
        ]);

        _runCmdSync('openssl', <String>[
          'req',
          '-x509',
          '-new',
          '-key',
          '${testDir.path}/ec_key.pem',
          '-out',
          '${testDir.path}/ec_cert.pem',
          '-days',
          '365',
          '-subj',
          '/CN=EC User',
          '-addext',
          'keyUsage=digitalSignature'
        ]);

        final String privateKeyPem =
            File('${testDir.path}/ec_key.pem').readAsStringSync();
        final String certificatePem =
            File('${testDir.path}/ec_cert.pem').readAsStringSync();

        final Uint8List content = Uint8List.fromList(
          utf8.encode('cms-detached-test-content-ec'),
        );
        final Uint8List digest =
            Uint8List.fromList(sha256.convert(content).bytes);

        final Uint8List cmsDer =
            PdfCmsSigner.signDetachedSha256EcdsaFromPem(
          contentDigest: digest,
          privateKeyPem: privateKeyPem,
          certificatePem: certificatePem,
          chainPem: const <String>[],
        );

        expect(cmsDer, isNotEmpty);

        final PdfSignatureValidation validator = PdfSignatureValidation();
        final result = validator.validateCmsSignedData(cmsDer);
        expect(result.cmsSignatureValid, isTrue);
        expect(result.certsPem, isNotEmpty);
      } finally {
        if (testDir.existsSync()) {
          testDir.deleteSync(recursive: true);
        }
      }
    });
  });
}

bool _hasOpenSsl() {
  try {
    final ProcessResult result = Process.runSync('openssl', const ['version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

void _runCmdSync(String cmd, List<String> args) {
  final result = Process.runSync(cmd, args);
  if (result.exitCode != 0) {
    throw Exception(
        'Command failed: $cmd ${args.join(' ')}\nStderr: ${result.stderr}');
  }
}
