import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/extra/pdf_signature_validator.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/security/chain/icp_brasil_provider.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/security/chain/iti_provider.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/security/chain/serpro_provider.dart';
import 'package:test/test.dart';

String _derToPem(Uint8List der) {
  final String base64Cert = base64.encode(der);
  final StringBuffer buffer = StringBuffer();
  buffer.writeln('-----BEGIN CERTIFICATE-----');
  for (int i = 0; i < base64Cert.length; i += 64) {
    buffer.writeln(base64Cert.substring(
        i, (i + 64 < base64Cert.length) ? i + 64 : base64Cert.length));
  }
  buffer.writeln('-----END CERTIFICATE-----');
  return buffer.toString();
}

void main() {
  group('ICP-Brasil and Gov.br Signature Compliance', () {
    final List<String> trustedRoots = <String>[];

    setUpAll(() async {
      final icp = IcpBrasilProvider();
      final iti = ItiProvider();
      final serpro = SerproProvider();

      for (final c in await icp.getTrustedRoots()) {
        trustedRoots.add(_derToPem(c));
      }
      for (final c in await iti.getTrustedRoots()) {
        trustedRoots.add(_derToPem(c));
      }
      for (final c in await serpro.getTrustedRoots()) {
        trustedRoots.add(_derToPem(c));
      }
    });

    test('Validate Gov.br signed PDF (sample_govbr_signature_assinado.pdf)',
        () async {
      final File file = File('test/assets/sample_govbr_signature_assinado.pdf');
      if (!file.existsSync()) {
        return;
      }

      final List<int> bytes = file.readAsBytesSync();

      final PdfSignatureValidator validator = PdfSignatureValidator();
      final PdfSignatureValidationReport report =
          await validator.validateAllSignatures(
        Uint8List.fromList(bytes),
        fetchCrls: true,
        trustedRootsPem: trustedRoots,
      );

      expect(report.signatures.isNotEmpty, isTrue,
          reason: 'Gov.br file should have at least one signature');

      for (final PdfSignatureValidationItem sig in report.signatures) {
        expect(sig.validation.cmsSignatureValid, isTrue,
            reason: 'CMS signature must be valid');

        expect(sig.validation.documentIntact, isTrue,
            reason: 'Document must not be modified');

        expect(sig.timestampStatus, isNotNull);
        expect(sig.timestampStatus!.present, isA<bool>());

        if (sig.validation.policyOid != null &&
            sig.validation.policyOid!.startsWith('2.16.76.1.7.1.')) {
          if (sig.timestampStatus!.present == false) {
            expect(
              sig.issues.any((i) =>
                  i.code == 'timestamp_missing' &&
                  i.severity.name == 'warning'),
              isTrue,
              reason:
                  'Missing timestamp should be warning for ICP-Brasil/Gov.br',
            );
          }
        }

        if (sig.validation.policyOid != null) {
          if (sig.policyStatus != null) {
            expect(sig.policyStatus!.valid, isTrue,
                reason: 'Policy validation failed');
          }
        }
      }
    },
        skip: File('test/assets/sample_govbr_signature_assinado.pdf').existsSync()
            ? false
            : 'Missing test asset: test/assets/sample_govbr_signature_assinado.pdf');

    test(
        'Validate ICP-Brasil Token signed PDF (sample_token_icpbrasil_assinado.pdf)',
        () async {
      final File file = File('test/assets/sample_token_icpbrasil_assinado.pdf');
      if (!file.existsSync()) {
        return;
      }

      final List<int> bytes = file.readAsBytesSync();

      final PdfSignatureValidator validator = PdfSignatureValidator();
      final PdfSignatureValidationReport report =
          await validator.validateAllSignatures(
        Uint8List.fromList(bytes),
        fetchCrls: true,
        trustedRootsPem: trustedRoots,
      );

      expect(report.signatures.isNotEmpty, isTrue);

      for (final PdfSignatureValidationItem sig in report.signatures) {
        expect(sig.validation.cmsSignatureValid, isTrue,
            reason: 'CMS signature must be valid');
      }
    },
        skip: File('test/assets/sample_token_icpbrasil_assinado.pdf').existsSync()
            ? false
            : 'Missing test asset: test/assets/sample_token_icpbrasil_assinado.pdf');
  });
}
