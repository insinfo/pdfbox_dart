import 'dart:io';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/crypto/x509/core/x509_certificates.dart';
import 'package:pdfbox_dart/src/crypto/x509/core/x509_utils.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/external_pdf_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/pdf_ltv_manager.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/pdf_signature_validator.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:test/test.dart';

void main() {
  final bool hasOpenSsl = _hasOpenSsl();

  test('PdfLtvManager creates DSS and VRI dictionaries', () async {
    if (!hasOpenSsl) return;

    final Directory testDir =
        await Directory.systemTemp.createTemp('ltv_test_');
    try {
      final String keyPath = '${testDir.path}/user_key.pem';
      final String certPath = '${testDir.path}/user_cert.pem';

      await _runCmd('openssl', <String>[
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-keyout',
        keyPath,
        '-out',
        certPath,
        '-days',
        '365',
        '-nodes',
        '-subj',
        '/CN=LTV Test User',
        '-addext',
        'keyUsage=digitalSignature'
      ]);

      final docBuilder = PDDocument();
      docBuilder.addPage(PDPage());
      final unsignedPdf = Uint8List.fromList(docBuilder.saveToBytes());
      docBuilder.close();

      final Uint8List signedPdf = await _externallySignWithOpenSsl(
        pdfBytes: unsignedPdf,
        fieldName: 'Sig1',
        keyPath: keyPath,
        certPath: certPath,
        workDir: testDir,
      );

      final doc = PDDocument.loadFromBytes(signedPdf);
      final ltvManager = PdfLtvManager(doc);

      final String certPem = File(certPath).readAsStringSync();
      final X509Certificate root = X509Utils.parsePemCertificate(certPem);

      await ltvManager.enableLtv(
        signedPdf,
        trustedRoots: <X509Certificate>[root],
        addVri: true,
      );

      final original = RandomAccessReadBuffer.fromBytes(signedPdf);
      final target = RandomAccessReadWriteBuffer();
      doc.saveIncremental(original, target);
      target.seek(0);
      final Uint8List ltvBytes = Uint8List(target.length);
      if (target.length > 0) {
        target.readFully(ltvBytes);
      }
      target.close();
      original.close();

      // Also verify a full save after LTV update succeeds and keeps DSS/VRI,
      // while acknowledging that a full rewrite invalidates the original signature.
      final Uint8List ltvBytesFull = Uint8List.fromList(doc.saveToBytes());
      doc.close();

      final PdfSignatureValidator validator = PdfSignatureValidator();

      final PdfSignatureValidationReport reportIncremental =
          await validator.validateAllSignatures(
        ltvBytes,
        trustedRootsPem: <String>[certPem],
      );
      final PdfSignatureValidationItem sigIncremental =
          reportIncremental.signatures.first;

      expect(sigIncremental.validation.cmsSignatureValid, isTrue,
          reason: 'CMS signature must remain valid in incremental save');
      expect(sigIncremental.validation.documentIntact, isTrue,
          reason: 'Document must remain intact after incremental save');
      expect(sigIncremental.ltv.hasDss, isTrue,
          reason: 'DSS Dictionary should be present');
      expect(sigIncremental.ltv.dssCertsCount, greaterThanOrEqualTo(1),
          reason: 'DSS should contain the signer certificate');
      expect(sigIncremental.ltv.signatureHasVri, isTrue,
          reason: 'VRI should be created for the signature');

      final PdfSignatureValidationReport reportFull =
          await validator.validateAllSignatures(
        ltvBytesFull,
        trustedRootsPem: <String>[certPem],
      );
      final PdfSignatureValidationItem sigFull = reportFull.signatures.first;

      expect(sigFull.ltv.hasDss, isTrue,
          reason: 'DSS Dictionary should be present after full save');
      expect(sigFull.ltv.dssCertsCount, greaterThanOrEqualTo(1),
          reason: 'DSS should contain the signer certificate after full save');
      expect(sigFull.ltv.signatureHasVri, isTrue,
          reason: 'VRI should be created for the signature after full save');
    } finally {
      if (testDir.existsSync()) testDir.deleteSync(recursive: true);
    }
  }, skip: hasOpenSsl ? false : 'openssl not available');
}

Future<Uint8List> _externallySignWithOpenSsl({
  required Uint8List pdfBytes,
  required String fieldName,
  required String keyPath,
  required String certPath,
  required Directory workDir,
}) async {
  final PDSignature signature = PDSignature()
    ..setContactInfo('Unit test')
    ..setReason('LTV test');

  final PdfExternalSigningResult prepared = await PdfExternalSigning.preparePdf(
    inputBytes: Uint8List.fromList(pdfBytes),
    pageNumber: 1,
    bounds: PDRectangle(100, 100, 300, 150),
    fieldName: fieldName,
    signature: signature,
    reservedSignatureSize: 0x4000,
  );

  final Uint8List preparedBytes = prepared.preparedPdfBytes;
  final List<int> ranges = PdfExternalSigning.extractByteRange(preparedBytes);

  final int start1 = ranges[0];
  final int len1 = ranges[1];
  final int start2 = ranges[2];
  final int len2 = ranges[3];

  final List<int> part1 = preparedBytes.sublist(start1, start1 + len1);
  final List<int> part2 = preparedBytes.sublist(start2, start2 + len2);

  final String dataToSignPath = '${workDir.path}/data_to_sign_$fieldName.bin';
  final IOSink dataSink = File(dataToSignPath).openWrite();
  dataSink.add(part1);
  dataSink.add(part2);
  await dataSink.close();

  final String p7sPath = '${workDir.path}/signature_$fieldName.p7s';

  await _runCmd('openssl', <String>[
    'smime',
    '-sign',
    '-binary',
    '-in',
    dataToSignPath.replaceAll('/', Platform.pathSeparator),
    '-signer',
    certPath.replaceAll('/', Platform.pathSeparator),
    '-inkey',
    keyPath.replaceAll('/', Platform.pathSeparator),
    '-out',
    p7sPath.replaceAll('/', Platform.pathSeparator),
    '-outform',
    'DER'
  ]);

  final Uint8List sigBytes =
      Uint8List.fromList(File(p7sPath).readAsBytesSync());
  return PdfExternalSigning.embedSignature(
    preparedPdfBytes: preparedBytes,
    pkcs7Bytes: sigBytes,
  );
}

bool _hasOpenSsl() {
  try {
    final ProcessResult result =
        Process.runSync('openssl', const <String>['version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<void> _runCmd(String cmd, List<String> args) async {
  final ProcessResult res = await Process.run(cmd, args);
  if (res.exitCode != 0) {
    throw Exception('Command failed: $cmd ${args.join(' ')}\n${res.stderr}');
  }
}
