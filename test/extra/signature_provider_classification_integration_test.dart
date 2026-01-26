import 'dart:io';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/extra/pdf_signature_validator.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/security/signer_classifier.dart';
import 'package:test/test.dart';

void main() {
  test('Classifies SERPRO signatures', () async {
    final PdfSignatureValidationReport r1 =
        await _validate('test/assets/serpro_Maurício_Soares_dos_Anjos.pdf');
    expect(r1.signatures, isNotEmpty);
    expect(
      classifySignerFromCertificatesPem(r1.signatures.first.validation.certsPem)
          .providerLabel,
      'serpro',
    );

    final PdfSignatureValidationReport r2 =
        await _validate('test/assets/carlos_augusto.pdf');
    expect(r2.signatures, isNotEmpty);
    expect(
      classifySignerFromCertificatesPem(r2.signatures.first.validation.certsPem)
          .providerLabel,
      'serpro',
    );
  },
      skip: File('test/assets/serpro_Maurício_Soares_dos_Anjos.pdf').existsSync() &&
              File('test/assets/carlos_augusto.pdf').existsSync()
          ? false
          : 'Missing test assets for SERPRO classification');

  test('Classifies gov.br signatures', () async {
    final PdfSignatureValidationReport r =
        await _validate('test/assets/sample_govbr_signature_assinado.pdf');
    expect(r.signatures, isNotEmpty);
    expect(
      classifySignerFromCertificatesPem(r.signatures.first.validation.certsPem)
          .providerLabel,
      'gov.br',
    );
  },
      skip: File('test/assets/sample_govbr_signature_assinado.pdf').existsSync()
          ? false
          : 'Missing test asset: test/assets/sample_govbr_signature_assinado.pdf');

  test('Classifies Certisign signatures (OAB chain)', () async {
    final PdfSignatureValidationReport r =
        await _validate('test/assets/sample_token_icpbrasil_assinado.pdf');
    expect(r.signatures, isNotEmpty);
    expect(
      classifySignerFromCertificatesPem(r.signatures.first.validation.certsPem)
          .providerLabel,
      'certisign',
    );
  },
      skip: File('test/assets/sample_token_icpbrasil_assinado.pdf').existsSync()
          ? false
          : 'Missing test asset: test/assets/sample_token_icpbrasil_assinado.pdf');
}

Future<PdfSignatureValidationReport> _validate(String path) async {
  final File f = File(path);
  if (!f.existsSync()) {
    throw Exception('Missing test asset: $path');
  }
  final Uint8List bytes = f.readAsBytesSync();
  return PdfSignatureValidator().validateAllSignatures(bytes);
}
