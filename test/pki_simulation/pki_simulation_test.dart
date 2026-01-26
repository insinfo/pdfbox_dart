import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';


import 'package:crypto/crypto.dart' as crypto;
import 'package:pdfbox_dart/src/crypto/basic_utils/core/crypto_utils.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/external_pdf_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/pdf_signature_validator.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/security/pdf_cms_signer.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';

import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pki/pki_builder.dart';
import 'package:pdfbox_dart/src/pki/pki_server.dart';

void main() {
  group('PKI Simulation & PDF Signing', () {
    late PkiServer server;
    late int serverPort;

    late AsymmetricKeyPair<PublicKey, PrivateKey> rootKey;
    late Uint8List rootCert;

    late AsymmetricKeyPair<PublicKey, PrivateKey> interKey;
    late Uint8List interCert;

    late AsymmetricKeyPair<PublicKey, PrivateKey> userKey;
    late Uint8List userCert;

    setUpAll(() async {
      rootKey = PkiUtils.generateRsaKeyPair(bitStrength: 2048);
      interKey = PkiUtils.generateRsaKeyPair(bitStrength: 2048);
      userKey = PkiUtils.generateRsaKeyPair(bitStrength: 2048);

      serverPort = await _findAvailablePort();
      final String serverBaseUrl = 'http://localhost:$serverPort';

      rootCert = PkiBuilder.createRootCertificate(
        keyPair: rootKey,
        dn: 'CN=Test Root CA,O=DartPDF',
      );

      interCert = PkiBuilder.createIntermediateCertificate(
        keyPair: interKey,
        issuerKeyPair: rootKey,
        subjectDn: 'CN=Test Intermediate CA,O=DartPDF',
        issuerDn: 'CN=Test Root CA,O=DartPDF',
        serialNumber: 100,
        crlUrls: <String>['$serverBaseUrl/crl'],
        ocspUrls: <String>['$serverBaseUrl/ocsp'],
      );

      userCert = PkiBuilder.createUserCertificate(
        keyPair: userKey,
        issuerKeyPair: interKey,
        subjectDn: 'CN=Test User,O=DartPDF,C=BR',
        issuerDn: 'CN=Test Intermediate CA,O=DartPDF',
        serialNumber: 200,
        crlUrls: <String>['$serverBaseUrl/crl'],
        ocspUrls: <String>['$serverBaseUrl/ocsp'],
      );

      final tsaKey = PkiUtils.generateRsaKeyPair(bitStrength: 2048);
      server = PkiServer(
        port: serverPort,
        revokedSerials: <int, bool>{},
        crlDer: Uint8List(0),
        tsaKeyPair: tsaKey,
        tsaCertChain: <AsymmetricKeyPair<PublicKey, PrivateKey>>[tsaKey],
      );
      await server.start();
    });

    tearDownAll(() async {
      await server.stop();
    });

    Future<Uint8List> generateSignedPdf() async {
      final PDDocument document = PDDocument();
      document.addPage(PDPage());
      final Uint8List inputBytes = Uint8List.fromList(document.saveToBytes());
      document.close();

      final PdfExternalSigningResult prepared =
          await PdfExternalSigning.preparePdf(
        inputBytes: inputBytes,
        pageNumber: 1,
        bounds: PDRectangle(0, 0, 200, 50),
        fieldName: 'Signature1',
        signature: PDSignature(),
      );

      final Uint8List digest = _computeByteRangeDigest(
        prepared.preparedPdfBytes,
        prepared.byteRange,
      );

      final String userPem = _certToPem(userCert);
      final String interPem = _certToPem(interCert);
      final String rootPem = _certToPem(rootCert);
      final String userKeyPem =
          _rsaPrivateKeyToPem(userKey.privateKey as RSAPrivateKey);

      final Uint8List pkcs7 = PdfCmsSigner.signDetachedSha256RsaFromPem(
        contentDigest: digest,
        privateKeyPem: userKeyPem,
        certificatePem: userPem,
        chainPem: <String>[interPem, rootPem],
      );

      return PdfExternalSigning.embedSignature(
        preparedPdfBytes: prepared.preparedPdfBytes,
        pkcs7Bytes: pkcs7,
      );
    }

    test('Validate Certificate Chain Embedding in PDF', () async {
      final Uint8List pdfBytes = await generateSignedPdf();

      final PdfSignatureValidator validator = PdfSignatureValidator();
      final PdfSignatureValidationReport report =
          await validator.validateAllSignatures(
        pdfBytes,
        trustedRootsPem: const <String>[],
        fetchCrls: false,
      );

      expect(report.signatures, hasLength(1));
      final PdfSignatureValidationItem sig = report.signatures.first;
      expect(sig.validation.certsPem.length, greaterThanOrEqualTo(2));
    });

    test('Validate Signature Chain Trust (Success Case)', () async {
      final Uint8List pdfBytes = await generateSignedPdf();
      final String rootPem = _certToPem(rootCert);

      final PdfSignatureValidator validator = PdfSignatureValidator();
      final PdfSignatureValidationReport report =
          await validator.validateAllSignatures(
        pdfBytes,
        trustedRootsPem: <String>[rootPem],
        fetchCrls: true,
      );

      final PdfSignatureValidationItem sig = report.signatures.first;
      expect(sig.chainTrusted, isTrue,
          reason: 'Chain should be trusted when Root is provided');
    });

    test('Validate Signature Chain Trust (Failure Case - Missing Root)', () async {
      final Uint8List pdfBytes = await generateSignedPdf();

      final PdfSignatureValidator validator = PdfSignatureValidator();
      final PdfSignatureValidationReport report =
          await validator.validateAllSignatures(
        pdfBytes,
        trustedRootsPem: const <String>[],
        fetchCrls: false,
      );

      final PdfSignatureValidationItem sig = report.signatures.first;
      expect(sig.chainTrusted, isNull,
          reason: 'Chain trust should be NULL without Root CA provided');
    });

    test('Sign Multiple PDFs in Parallel with External Signer', () async {
      final futures = List.generate(3, (int index) async {
        final PDDocument document = PDDocument();
        document.addPage(PDPage());
        final Uint8List inputBytes =
            Uint8List.fromList(document.saveToBytes());
        document.close();

        final PdfExternalSigningResult prepared =
            await PdfExternalSigning.preparePdf(
          inputBytes: inputBytes,
          pageNumber: 1,
          bounds: PDRectangle(0, 0, 200, 50),
          fieldName: 'Signature$index',
          signature: PDSignature(),
        );

        final Uint8List digest = _computeByteRangeDigest(
          prepared.preparedPdfBytes,
          prepared.byteRange,
        );

        final String userPem = _certToPem(userCert);
        final String interPem = _certToPem(interCert);
        final String rootPem = _certToPem(rootCert);
        final String userKeyPem =
            _rsaPrivateKeyToPem(userKey.privateKey as RSAPrivateKey);

        final Uint8List pkcs7 = PdfCmsSigner.signDetachedSha256RsaFromPem(
          contentDigest: digest,
          privateKeyPem: userKeyPem,
          certificatePem: userPem,
          chainPem: <String>[interPem, rootPem],
        );

        final Uint8List signedBytes = PdfExternalSigning.embedSignature(
          preparedPdfBytes: prepared.preparedPdfBytes,
          pkcs7Bytes: pkcs7,
        );

        final PdfSignatureValidator validator = PdfSignatureValidator();
        final PdfSignatureValidationReport report =
            await validator.validateAllSignatures(
          signedBytes,
          trustedRootsPem: <String>[rootPem],
          fetchCrls: true,
          strictRevocation: false,
        );

        final PdfSignatureValidationItem sig = report.signatures.first;
        if (!sig.validation.cmsSignatureValid ||
            sig.chainTrusted != true) {
          throw Exception('Validation failed for document $index');
        }

        return signedBytes.length;
      });

      final List<int> results = await Future.wait(futures);
      expect(results.length, 3);
      expect(results.every((size) => size > 0), isTrue);
    });
  });
}

Future<int> _findAvailablePort() async {
  final ServerSocket socket =
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final int port = socket.port;
  await socket.close();
  return port;
}

String _certToPem(Uint8List der) {
  final String base64Str = base64.encode(der);
  final List<String> chunks = _chunk(base64Str, 64);
  return '-----BEGIN CERTIFICATE-----\n${chunks.join('\n')}\n-----END CERTIFICATE-----';
}

String _rsaPrivateKeyToPem(RSAPrivateKey key) {
  return CryptoUtils.encodeRSAPrivateKeyToPem(key);
}

List<String> _chunk(String text, int size) {
  final List<String> result = <String>[];
  for (int i = 0; i < text.length; i += size) {
    result.add(text.substring(i, i + size > text.length ? text.length : i + size));
  }
  return result;
}

Uint8List _computeByteRangeDigest(Uint8List bytes, List<int> byteRange) {
  final int start1 = byteRange[0];
  final int len1 = byteRange[1];
  final int start2 = byteRange[2];
  final int len2 = byteRange[3];

  final BytesBuilder builder = BytesBuilder();
  builder.add(bytes.sublist(start1, start1 + len1));
  builder.add(bytes.sublist(start2, start2 + len2));

  final crypto.Digest digest = crypto.sha256.convert(builder.takeBytes());
  return Uint8List.fromList(digest.bytes);
}
