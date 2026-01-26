import 'dart:io';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/crypto/asn1/core/legacy_der.dart';
import 'package:pdfbox_dart/src/crypto/x509/core/x509_certificates.dart';
import 'package:pdfbox_dart/src/crypto/x509/core/x509_name.dart';
import 'package:pdfbox_dart/src/crypto/x509/core/x509_utils.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/pdf_signature_validator.dart';
import 'package:test/test.dart';

void main() {
  final Map<DerObjectID, String> symbols = <DerObjectID, String>{
    X509Name.cn: 'CN',
    X509Name.o: 'O',
    X509Name.ou: 'OU',
    X509Name.c: 'C',
    X509Name.st: 'ST',
    X509Name.l: 'L',
    X509Name.emailAddress: 'E',
  };

  test('Validate "2 ass leonardo e mauricio.pdf"', () async {
    final File file = File('test/assets/2 ass leonardo e mauricio.pdf');
    if (!file.existsSync()) {
      return;
    }

    final Uint8List bytes = file.readAsBytesSync();
    final PdfSignatureValidator validator = PdfSignatureValidator();

    final PdfSignatureValidationReport report =
        await validator.validateAllSignatures(
      bytes,
      useEmbeddedIcpBrasil: true,
      fetchCrls: false,
    );

    expect(report.signatures.length, equals(2));

    bool foundLeonardo = false;
    bool foundMauricio = false;

    for (final PdfSignatureValidationItem sig in report.signatures) {
      expect(sig.validation.cmsSignatureValid, isTrue,
          reason: 'Signature ${sig.fieldName} invalid');

      expect(sig.validation.certsPem, isNotEmpty);
      final X509Certificate signerCert =
          X509Utils.parsePemCertificate(sig.validation.certsPem.first);

      final String subjectStr =
          signerCert.c!.subject!.getString(false, symbols).toLowerCase();
      final String issuerStr =
          signerCert.c!.issuer!.getString(false, symbols).toLowerCase();

      expect(sig.chainTrusted, isTrue,
          reason: 'Chain not trusted for ${sig.fieldName}');

      if (subjectStr.contains('leonardo')) {
        foundLeonardo = true;
        expect(issuerStr, contains('gov-br'),
            reason: 'Leonardo should be issued by Gov.BR (gov-br)');
      } else if (subjectStr.contains('mauricio')) {
        foundMauricio = true;
        expect(issuerStr, contains('serpro'),
            reason: 'Mauricio should be issued by Serpro');
      }
    }

    expect(foundLeonardo, isTrue, reason: 'Leonardo signature not found');
    expect(foundMauricio, isTrue, reason: 'Mauricio signature not found');
  },
      skip: File('test/assets/2 ass leonardo e mauricio.pdf').existsSync()
          ? false
          : 'Missing test asset: test/assets/2 ass leonardo e mauricio.pdf');

  test('Validate "3 ass leonardo e stefan e mauricio.pdf"', () async {
    final File file = File('test/assets/3 ass leonardo e stefan e mauricio.pdf');
    if (!file.existsSync()) {
      return;
    }

    final Uint8List bytes = file.readAsBytesSync();
    final PdfSignatureValidator validator = PdfSignatureValidator();

    final PdfSignatureValidationReport report =
        await validator.validateAllSignatures(
      bytes,
      useEmbeddedIcpBrasil: true,
      fetchCrls: false,
    );

    expect(report.signatures.length, equals(3));

    bool foundLeonardo = false;
    bool foundStefan = false;
    bool foundMauricio = false;

    for (final PdfSignatureValidationItem sig in report.signatures) {
      expect(sig.validation.cmsSignatureValid, isTrue);

      final X509Certificate signerCert =
          X509Utils.parsePemCertificate(sig.validation.certsPem.first);
      final String subjectStr =
          signerCert.c!.subject!.getString(false, symbols).toLowerCase();
      final String issuerStr =
          signerCert.c!.issuer!.getString(false, symbols).toLowerCase();

      expect(sig.chainTrusted, isTrue,
          reason: 'Chain not trusted for ${sig.fieldName}');

      if (subjectStr.contains('leonardo')) {
        foundLeonardo = true;
        expect(issuerStr, contains('gov-br'),
            reason: 'Leonardo should be issued by Gov.BR (gov-br)');
      } else if (subjectStr.contains('stefan')) {
        foundStefan = true;
      } else if (subjectStr.contains('mauricio')) {
        foundMauricio = true;
        expect(issuerStr, contains('serpro'),
            reason: 'Mauricio should be issued by Serpro');
      }
    }

    expect(foundLeonardo, isTrue, reason: 'Leonardo signature not found');
    expect(foundStefan, isTrue, reason: 'Stefan signature not found');
    expect(foundMauricio, isTrue, reason: 'Mauricio signature not found');
  },
      skip: File('test/assets/3 ass leonardo e stefan e mauricio.pdf')
              .existsSync()
          ? false
          : 'Missing test asset: test/assets/3 ass leonardo e stefan e mauricio.pdf');

  test('Validate "serpro_Maurício_Soares_dos_Anjos.pdf"', () async {
    final File file = File('test/assets/serpro_Maurício_Soares_dos_Anjos.pdf');
    if (!file.existsSync()) {
      return;
    }

    final Uint8List bytes = file.readAsBytesSync();
    final PdfSignatureValidator validator = PdfSignatureValidator();

    final PdfSignatureValidationReport report =
        await validator.validateAllSignatures(
      bytes,
      useEmbeddedIcpBrasil: true,
      fetchCrls: false,
    );

    expect(report.signatures, isNotEmpty);

    for (final PdfSignatureValidationItem sig in report.signatures) {
      expect(sig.validation.cmsSignatureValid, isTrue);
      expect(sig.chainTrusted, isTrue,
          reason: 'Chain not trusted for ${sig.fieldName}');
    }
  },
      skip: File('test/assets/serpro_Maurício_Soares_dos_Anjos.pdf')
              .existsSync()
          ? false
          : 'Missing test asset: test/assets/serpro_Maurício_Soares_dos_Anjos.pdf');

  test('Validate "sample_token_icpbrasil_assinado.pdf"', () async {
    final File file = File('test/assets/sample_token_icpbrasil_assinado.pdf');
    if (!file.existsSync()) {
      return;
    }

    final Uint8List bytes = file.readAsBytesSync();
    final PdfSignatureValidator validator = PdfSignatureValidator();

    final PdfSignatureValidationReport report =
        await validator.validateAllSignatures(
      bytes,
      useEmbeddedIcpBrasil: true,
      fetchCrls: false,
    );

    expect(report.signatures, isNotEmpty);

    for (final PdfSignatureValidationItem sig in report.signatures) {
      expect(sig.validation.cmsSignatureValid, isTrue);
    }
  },
      skip: File('test/assets/sample_token_icpbrasil_assinado.pdf').existsSync()
          ? false
          : 'Missing test asset: test/assets/sample_token_icpbrasil_assinado.pdf');
}
