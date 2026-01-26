import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/extra/external_pdf_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/govbr_signature_api.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:test/test.dart';

void main() {
  final bool hasOpenSsl = _hasOpenSsl();

  test(
    'govbr integration flow signs PDF with mock server',
    () async {
      if (!hasOpenSsl) {
        return;
      }

      final Directory tempDir =
          await Directory.systemTemp.createTemp('govbr_integration_');
      HttpServer? server;
      try {
        final _CertChain chain = await _generateCertificateChain(tempDir);

        final Uint8List inputBytes = _createPdfBytes();

        final PdfExternalSigningResult prepared =
            await PdfExternalSigning.preparePdf(
          inputBytes: inputBytes,
          pageNumber: 1,
          bounds: PDRectangle(100, 100, 300, 150),
          fieldName: 'GovBr_Signature',
          signature: PDSignature(),
        );

        final List<int> byteRange =
            PdfExternalSigning.extractByteRange(prepared.preparedPdfBytes);
        final Uint8List dataToSign =
            _extractDataByRange(prepared.preparedPdfBytes, byteRange);
        final String expectedHashBase64 =
            PdfExternalSigning.computeByteRangeHashBase64(
          prepared.preparedPdfBytes,
          byteRange,
        );

        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final Uri baseUri =
            Uri.parse('http://127.0.0.1:${server.port}/externo/v2/');

        server.listen((HttpRequest request) async {
          try {
            if (request.method == 'GET' &&
                request.uri.path.endsWith('/certificadoPublico')) {
              final String pem = await File(chain.leafCertPath).readAsString();
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.contentType =
                  ContentType('text', 'plain');
              request.response.write(pem);
              await request.response.close();
              return;
            }

            if (request.method == 'POST' &&
                request.uri.path.endsWith('/assinarPKCS7')) {
              final String body = await utf8.decoder.bind(request).join();
              final Map<String, dynamic> jsonBody =
                  jsonDecode(body) as Map<String, dynamic>;
              final String hashBase64 =
                  (jsonBody['hashBase64'] ?? '').toString();
              if (hashBase64 != expectedHashBase64) {
                request.response.statusCode = HttpStatus.badRequest;
                request.response.write('invalid hash');
                await request.response.close();
                return;
              }

              final String dataPath =
                  '${tempDir.path}${Platform.pathSeparator}data.bin';
              await File(dataPath).writeAsBytes(dataToSign, flush: true);

              final String sigPath =
                  '${tempDir.path}${Platform.pathSeparator}sig.der';
              await _runCmd('openssl', <String>[
                'cms',
                '-sign',
                '-binary',
                '-in',
                dataPath,
                '-signer',
                chain.leafCertPath,
                '-inkey',
                chain.leafKeyPath,
                '-certfile',
                chain.chainCertPath,
                '-outform',
                'DER',
                '-out',
                sigPath,
              ]);

              final Uint8List sigBytes = await File(sigPath).readAsBytes();
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.contentType =
                  ContentType('application', 'octet-stream');
              request.response.add(sigBytes);
              await request.response.close();
              return;
            }

            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          } catch (e) {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write('error: $e');
            await request.response.close();
          }
        });

        final GovBrSignatureApi api = GovBrSignatureApi(
          baseUri: baseUri,
        );

        final String certPem =
            await api.getPublicCertificatePem('mock_access_token');
        expect(certPem.contains('BEGIN CERTIFICATE'), isTrue);

        final Uint8List pkcs7 = await api.signHashPkcs7(
          accessToken: 'mock_access_token',
          hashBase64: prepared.hashBase64,
        );
        expect(pkcs7.isNotEmpty, isTrue);

        final Uint8List signedPdf = PdfExternalSigning.embedSignature(
          preparedPdfBytes: prepared.preparedPdfBytes,
          pkcs7Bytes: pkcs7,
        );
        expect(signedPdf.length, equals(prepared.preparedPdfBytes.length));

        final String verifyDataPath =
            '${tempDir.path}${Platform.pathSeparator}verify_data.bin';
        await File(verifyDataPath).writeAsBytes(dataToSign, flush: true);
        final String verifySigPath =
            '${tempDir.path}${Platform.pathSeparator}verify_sig.der';
        await File(verifySigPath).writeAsBytes(pkcs7, flush: true);

        await _runCmd('openssl', <String>[
          'cms',
          '-verify',
          '-binary',
          '-in',
          verifySigPath,
          '-inform',
          'DER',
          '-content',
          verifyDataPath,
          '-CAfile',
          chain.rootCertPath,
        ]);
      } finally {
        await server?.close(force: true);
        await tempDir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: hasOpenSsl ? false : 'openssl not available',
  );

  test(
    'internal parser flags resolve ByteRange and Contents',
    () async {
      final Uint8List inputBytes = _createPdfBytes();

      PdfExternalSigning.useInternalByteRangeParser = true;
      PdfExternalSigning.useInternalContentsParser = true;
      try {
        final prepared = await PdfExternalSigning.preparePdf(
          inputBytes: inputBytes,
          pageNumber: 1,
          bounds: PDRectangle(100, 100, 300, 150),
          fieldName: 'Internal_Signature',
          signature: PDSignature(),
        );

        final byteRange =
            PdfExternalSigning.extractByteRange(prepared.preparedPdfBytes);
        expect(byteRange.length, equals(4));

        final contents =
            PdfExternalSigning.findContentsRange(prepared.preparedPdfBytes);
        expect(contents.end, greaterThan(contents.start));
      } finally {
        PdfExternalSigning.useInternalByteRangeParser = false;
        PdfExternalSigning.useInternalContentsParser = false;
      }
    },
  );
}

Uint8List _createPdfBytes() {
  final PDDocument doc = PDDocument();
  doc.addPage(PDPage());
  final Uint8List bytes = Uint8List.fromList(doc.saveToBytes());
  doc.close();
  return bytes;
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

Uint8List _extractDataByRange(Uint8List pdfBytes, List<int> byteRange) {
  if (byteRange.length != 4) {
    throw ArgumentError.value(byteRange, 'byteRange', 'Invalid length');
  }
  final int start1 = byteRange[0];
  final int len1 = byteRange[1];
  final int start2 = byteRange[2];
  final int len2 = byteRange[3];
  final BytesBuilder builder = BytesBuilder();
  builder.add(pdfBytes.sublist(start1, start1 + len1));
  builder.add(pdfBytes.sublist(start2, start2 + len2));
  return builder.takeBytes();
}

Future<void> _runCmd(String cmd, List<String> args) async {
  final ProcessResult result = await Process.run(cmd, args);
  if (result.exitCode != 0) {
    throw Exception(
      'Command failed: $cmd ${args.join(' ')}\n'
      'stdout: ${result.stdout}\n'
      'stderr: ${result.stderr}',
    );
  }
}

Future<_CertChain> _generateCertificateChain(Directory dir) async {
  final String rootKey = '${dir.path}${Platform.pathSeparator}root_key.pem';
  final String rootCert = '${dir.path}${Platform.pathSeparator}root_cert.pem';
  await _runCmd('openssl', <String>[
    'req',
    '-x509',
    '-newkey',
    'rsa:2048',
    '-nodes',
    '-keyout',
    rootKey,
    '-out',
    rootCert,
    '-days',
    '3650',
    '-subj',
    '/CN=Test Root CA',
    '-addext',
    'basicConstraints=CA:TRUE',
    '-addext',
    'keyUsage=keyCertSign,cRLSign',
    '-addext',
    'subjectKeyIdentifier=hash',
  ]);

  final String intermediateKey =
      '${dir.path}${Platform.pathSeparator}intermediate_key.pem';
  final String intermediateCsr =
      '${dir.path}${Platform.pathSeparator}intermediate.csr';
  final String intermediateCert =
      '${dir.path}${Platform.pathSeparator}intermediate_cert.pem';
  await _runCmd('openssl', <String>[
    'req',
    '-newkey',
    'rsa:2048',
    '-nodes',
    '-keyout',
    intermediateKey,
    '-out',
    intermediateCsr,
    '-subj',
    '/CN=Test Intermediate CA',
  ]);

  final String intermediateExt =
      '${dir.path}${Platform.pathSeparator}intermediate_ext.cnf';
  await File(intermediateExt).writeAsString('''
[v3_ca]
basicConstraints=CA:TRUE,pathlen:0
keyUsage=keyCertSign,cRLSign
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
''');
  await _runCmd('openssl', <String>[
    'x509',
    '-req',
    '-in',
    intermediateCsr,
    '-CA',
    rootCert,
    '-CAkey',
    rootKey,
    '-CAcreateserial',
    '-out',
    intermediateCert,
    '-days',
    '3650',
    '-extfile',
    intermediateExt,
    '-extensions',
    'v3_ca',
  ]);

  final String leafKey = '${dir.path}${Platform.pathSeparator}leaf_key.pem';
  final String leafCsr = '${dir.path}${Platform.pathSeparator}leaf.csr';
  final String leafCert = '${dir.path}${Platform.pathSeparator}leaf_cert.pem';
  await _runCmd('openssl', <String>[
    'req',
    '-newkey',
    'rsa:2048',
    '-nodes',
    '-keyout',
    leafKey,
    '-out',
    leafCsr,
    '-subj',
    '/CN=Test User',
  ]);

  final String leafExt = '${dir.path}${Platform.pathSeparator}leaf_ext.cnf';
  await File(leafExt).writeAsString('''
[v3_usr]
basicConstraints=CA:FALSE
keyUsage=digitalSignature
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
''');
  await _runCmd('openssl', <String>[
    'x509',
    '-req',
    '-in',
    leafCsr,
    '-CA',
    intermediateCert,
    '-CAkey',
    intermediateKey,
    '-CAcreateserial',
    '-out',
    leafCert,
    '-days',
    '365',
    '-extfile',
    leafExt,
    '-extensions',
    'v3_usr',
  ]);

  final String chainCertPath =
      '${dir.path}${Platform.pathSeparator}chain.pem';
  final String chainPem =
      '${File(intermediateCert).readAsStringSync()}\n${File(rootCert).readAsStringSync()}\n';
  await File(chainCertPath).writeAsString(chainPem);

  return _CertChain(
    rootCertPath: rootCert,
    chainCertPath: chainCertPath,
    leafCertPath: leafCert,
    leafKeyPath: leafKey,
  );
}

class _CertChain {
  const _CertChain({
    required this.rootCertPath,
    required this.chainCertPath,
    required this.leafCertPath,
    required this.leafKeyPath,
  });

  final String rootCertPath;
  final String chainCertPath;
  final String leafCertPath;
  final String leafKeyPath;
}
