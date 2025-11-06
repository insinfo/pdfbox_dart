import 'dart:io';
import 'package:pdfbox_dart/src/utils/pdf_signature_validation.dart';
import 'package:pdfbox_dart/basic_utils.dart';

/// Utilitário puro Dart para validar uma assinatura digital PDF (CMS/PKCS#7)
/// e a cadeia de certificados, sem usar OpenSSL.
///
/// Uso:
///   dart scripts/validate_pdf_signature.dart documento.pdf
///
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print(
        'Uso: dart scripts/validate_pdf_signature.dart <arquivo.pdf> [--verbose]');
    exit(64);
  }
  final filePath = args.first;
  final verbose = args.contains('--verbose');
  final pdfBytes = await File(filePath).readAsBytes();

  String? userCrtPem;
  if (File('user.crt').existsSync()) {
    userCrtPem = File('user.crt').readAsStringSync();
  }

  final result = PdfSignatureValidation()
      .validatePdfSignature(pdfBytes, verbose: verbose, userCrtPem: userCrtPem);

  print('\n=== Resultado da Validação (puro Dart) ===');
  print('Arquivo: $filePath');
  print('Assinatura CMS válida (RSA): ${result.cmsSignatureValid}');
  print('ByteRange/Hash confere: ${result.byteRangeDigestOk}');
  print('Documento íntegro (RSA + Hash): ${result.documentIntact}');
  print('Quantidade de certificados no CMS: ${result.certsPem.length}');
  if (result.certsPem.isNotEmpty) {
    final leaf = X509Utils.x509CertificateFromPem(result.certsPem.first);
    final subject = leaf.tbsCertificate!.subject;
    final cn = subject['2.5.4.3'] ?? '';
    print('Assinado por (CN): $cn');
  }
  if (result.certsPem.length >= 2) {
    final chain = result.certsPem
        .map((pem) => X509Utils.x509CertificateFromPem(pem))
        .toList(growable: false);
    final chainCheck = X509Utils.checkChain(chain);
    final allPairsOk = chainCheck.pairs!.every(
      (p) => (p.dnDataMatch != false) && (p.signatureMatch != false),
    );
    print('Cadeia (assinatura DN/Signature entre pares): $allPairsOk');
  } else {
    print('Cadeia: apenas certificado do assinante presente no CMS.');
  }
}
