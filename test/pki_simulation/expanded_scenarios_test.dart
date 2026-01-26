import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/crypto/asn1/asn1.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pdfbox_dart/src/crypto/basic_utils/core/crypto_utils.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/external_pdf_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/pdf_signature_validator.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/security/pdf_cms_signer.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pki/pki_builder.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

void main() {
  group('Expanded Real World Scenarios', () {
    test(
        'Scenario 1: GovBr-Style 4-Level Chain Signature (Root -> Intermediate -> AC Final -> User)',
        () async {
      const String rootDn =
          'CN=Teste Autoridade Certificadora Raiz Brasileira v1, O=ICP-Brasil, C=BR';
      final rootKeyPair = PkiUtils.generateRsaKeyPair(bitStrength: 2048);
      final Uint8List rootCertDer = PkiBuilder.createRootCertificate(
        keyPair: rootKeyPair,
        dn: rootDn,
        validityYears: 20,
      );
      final String rootCertPem = _certToPem(rootCertDer);

      const String intermediateDn =
          'CN=Teste AC Intermediaria do Governo Federal do Brasil v1, O=ICP-Brasil, C=BR';
      final intermediateKeyPair = PkiUtils.generateRsaKeyPair(bitStrength: 2048);
      final Uint8List intermediateCertDer =
          PkiBuilder.createIntermediateCertificate(
        keyPair: intermediateKeyPair,
        issuerKeyPair: rootKeyPair,
        issuerDn: rootDn,
        subjectDn: intermediateDn,
        serialNumber: 2,
        validityYears: 10,
      );
      final String intermediateCertPem = _certToPem(intermediateCertDer);

      const String acFinalDn =
          'CN=Teste AC Final do Governo Federal do Brasil v1, O=ICP-Brasil, C=BR';
      final acFinalKeyPair = PkiUtils.generateRsaKeyPair(bitStrength: 2048);
      final Uint8List acFinalCertDer = PkiBuilder.createIntermediateCertificate(
        keyPair: acFinalKeyPair,
        issuerKeyPair: intermediateKeyPair,
        issuerDn: intermediateDn,
        subjectDn: acFinalDn,
        serialNumber: 3,
        validityYears: 5,
      );
      final String acFinalCertPem = _certToPem(acFinalCertDer);

      const String userDn =
          'CN=Isaque Neves Sant Ana, OU=Pessoa Fisica, O=ICP-Brasil, C=BR';
      final userKeyPair = PkiUtils.generateRsaKeyPair(bitStrength: 2048);
      final Uint8List userCertDer = PkiBuilder.createUserCertificate(
        keyPair: userKeyPair,
        issuerKeyPair: acFinalKeyPair,
        issuerDn: acFinalDn,
        subjectDn: userDn,
        serialNumber: 4,
        validityDays: 365 * 3,
      );
      final String userCertPem = _certToPem(userCertDer);
      final String userKeyPem =
          _rsaPrivateKeyToPem(userKeyPair.privateKey as RSAPrivateKey);

      await _exportChainAsP7b(
        <Uint8List>[userCertDer, acFinalCertDer, intermediateCertDer, rootCertDer],
        'test/tmp/Cadeia_Test-der.p7b',
      );

      await File('test/tmp/AC_Raiz_Test.pem').writeAsString(rootCertPem);
      await File('test/tmp/AC_Intermediaria_Test.pem')
          .writeAsString(intermediateCertPem);
      await File('test/tmp/AC_Final_Test.pem').writeAsString(acFinalCertPem);
      await File('test/tmp/Cert_Usuario_Isaque.pem').writeAsString(userCertPem);
      await File('test/tmp/Cert_Usuario_Isaque.key').writeAsString(userKeyPem);

      _validateChainLinkageFromDerList(
        <Uint8List>[userCertDer, acFinalCertDer, intermediateCertDer, rootCertDer],
      );

      final PDDocument doc = PDDocument();
      doc.addPage(PDPage());
      final Uint8List pdfBytes = Uint8List.fromList(doc.saveToBytes());
      doc.close();

      final PdfExternalSigningResult prepared =
          await PdfExternalSigning.preparePdf(
        inputBytes: pdfBytes,
        fieldName: 'AssinaturaGovBr_1',
        pageNumber: 1,
        bounds: PDRectangle(50, 50, 250, 100),
        signature: PDSignature(),
      );

      final Uint8List digestBytes = _computeByteRangeDigest(
        prepared.preparedPdfBytes,
        prepared.byteRange,
      );

      final Uint8List pkcs7 = PdfCmsSigner.signDetachedSha256RsaFromPem(
        contentDigest: digestBytes,
        privateKeyPem: userKeyPem,
        certificatePem: userCertPem,
        chainPem: <String>[acFinalCertPem, intermediateCertPem, rootCertPem],
      );

      _validatePkcs7Chain(pkcs7, 4);

      final Uint8List signedBytes = PdfExternalSigning.embedSignature(
        preparedPdfBytes: prepared.preparedPdfBytes,
        pkcs7Bytes: pkcs7,
      );

      final File outFile = File('test/tmp/out_scenario1_govbr_chain.pdf');
      if (!await outFile.parent.exists()) {
        await outFile.parent.create(recursive: true);
      }
      await outFile.writeAsBytes(signedBytes);

      final PdfSignatureValidator validator = PdfSignatureValidator();
      final PdfSignatureValidationReport report =
          await validator.validateAllSignatures(signedBytes);
      expect(report.signatures.length, 1);
      expect(report.signatures.first.validation.cmsSignatureValid, isTrue);
    });

    test('Scenario 2: Simple 2-Level Chain', () async {
      final rootKeyPair = PkiUtils.generateRsaKeyPair(bitStrength: 2048);
      final Uint8List rootCertDer = PkiBuilder.createRootCertificate(
        keyPair: rootKeyPair,
        dn: 'CN=AC Interna Root, O=Test Org, C=BR',
        validityYears: 10,
      );
      final String rootCertPem = _certToPem(rootCertDer);

      final userKeyPair = PkiUtils.generateRsaKeyPair(bitStrength: 2048);
      final Uint8List userCertDer = PkiBuilder.createUserCertificate(
        keyPair: userKeyPair,
        issuerKeyPair: rootKeyPair,
        issuerDn: 'CN=AC Interna Root, O=Test Org, C=BR',
        subjectDn: 'CN=User Internal, O=Test Org, C=BR',
        serialNumber: 2,
        validityDays: 365,
      );
      final String userCertPem = _certToPem(userCertDer);
      final String userKeyPem =
          _rsaPrivateKeyToPem(userKeyPair.privateKey as RSAPrivateKey);

      final PDDocument doc = PDDocument();
      doc.addPage(PDPage());
      final Uint8List pdfBytes = Uint8List.fromList(doc.saveToBytes());
      doc.close();

      final PdfExternalSigningResult prepared =
          await PdfExternalSigning.preparePdf(
        inputBytes: pdfBytes,
        fieldName: 'AssinaturaSimples_1',
        pageNumber: 1,
        bounds: PDRectangle(50, 50, 250, 100),
        signature: PDSignature(),
      );

      final Uint8List digestBytes = _computeByteRangeDigest(
        prepared.preparedPdfBytes,
        prepared.byteRange,
      );

      final Uint8List pkcs7 = PdfCmsSigner.signDetachedSha256RsaFromPem(
        contentDigest: digestBytes,
        privateKeyPem: userKeyPem,
        certificatePem: userCertPem,
        chainPem: <String>[rootCertPem],
      );

      _validatePkcs7Chain(pkcs7, 2);

      final Uint8List signedBytes = PdfExternalSigning.embedSignature(
        preparedPdfBytes: prepared.preparedPdfBytes,
        pkcs7Bytes: pkcs7,
      );

      final File file = File('test/tmp/out_scenario2_simple.pdf');
      await file.writeAsBytes(signedBytes);
    });

    test('Diagnostic: Verify Chain Linkage (DN and KeyID)', () {
      final rootKeyPair = PkiUtils.generateRsaKeyPair(bitStrength: 2048);
      final Uint8List rootCertDer = PkiBuilder.createRootCertificate(
        keyPair: rootKeyPair,
        dn: 'CN=Root CA, O=Test, C=US',
      );

      final userKeyPair = PkiUtils.generateRsaKeyPair(bitStrength: 2048);
      final Uint8List userCertDer = PkiBuilder.createUserCertificate(
        keyPair: userKeyPair,
        issuerKeyPair: rootKeyPair,
        issuerDn: 'CN=Root CA, O=Test, C=US',
        subjectDn: 'CN=User, O=Test, C=US',
        serialNumber: 123,
      );

      final ASN1Sequence rootCert =
          ASN1Parser(rootCertDer).nextObject() as ASN1Sequence;
      final ASN1Sequence userCert =
          ASN1Parser(userCertDer).nextObject() as ASN1Sequence;

      final ASN1Sequence rootTbs = rootCert.elements[0] as ASN1Sequence;
      final ASN1Sequence userTbs = userCert.elements[0] as ASN1Sequence;

      final Uint8List rootSubjectRaw = rootTbs.elements[5].encodedBytes;
      final Uint8List userIssuerRaw = userTbs.elements[3].encodedBytes;

      expect(
        _bytesToHex(userIssuerRaw),
        equals(_bytesToHex(rootSubjectRaw)),
        reason: 'User Issuer DN must match Root Subject DN byte-for-byte',
      );

      final ASN1Sequence? rootExts = _getExtensions(rootTbs);
      final ASN1Sequence? userExts = _getExtensions(userTbs);

      final Uint8List? rootSKI = _getExtensionValue(rootExts, '2.5.29.14');
      final Uint8List? userAKI = _getExtensionValue(userExts, '2.5.29.35');

      expect(rootSKI, isNotNull, reason: 'Root must have SKI');
      expect(userAKI, isNotNull, reason: 'User must have AKI');

      final ASN1Parser akiParser = ASN1Parser(userAKI!);
      final ASN1Sequence akiSeq = akiParser.nextObject() as ASN1Sequence;
      List<int> keyIdFromAki = <int>[];
      for (final el in akiSeq.elements) {
        if (el.tag == 0x80) {
          keyIdFromAki = el.valueBytes();
          break;
        }
      }

      final ASN1Parser skiParser = ASN1Parser(rootSKI!);
      final ASN1Object skiObj = skiParser.nextObject();
      final List<int> keyIdFromSki = skiObj.valueBytes();

      expect(
        _bytesToHex(Uint8List.fromList(keyIdFromAki)),
        equals(_bytesToHex(Uint8List.fromList(keyIdFromSki))),
        reason: 'User AKI KeyID must match Root SKI KeyID',
      );
    });

    test('Scenario 3: Multi-Signature (Internal + GovBr)', () async {
      final File initialPdfFile = File('test/tmp/out_scenario1_govbr_chain.pdf');
      if (!await initialPdfFile.exists()) {
        return;
      }
      final Uint8List initialPdfBytes = await initialPdfFile.readAsBytes();

      final govRootKeyPair = PkiUtils.generateRsaKeyPair();
      final Uint8List govRootCertDer = PkiBuilder.createRootCertificate(
        keyPair: govRootKeyPair,
        dn: 'CN=GovBr Root, O=GovBr, C=BR',
        validityYears: 20,
      );
      final String govRootCertPem = _certToPem(govRootCertDer);

      final citizenKeyPair = PkiUtils.generateRsaKeyPair();
      final Uint8List citizenCertDer = PkiBuilder.createUserCertificate(
        keyPair: citizenKeyPair,
        issuerKeyPair: govRootKeyPair,
        issuerDn: 'CN=GovBr Root, O=GovBr, C=BR',
        subjectDn: 'CN=Second Signer, O=GovBr, C=BR',
        serialNumber: 202,
        validityDays: 100,
      );
      final String citizenCertPem = _certToPem(citizenCertDer);
      final String citizenKeyPem =
          _rsaPrivateKeyToPem(citizenKeyPair.privateKey as RSAPrivateKey);

      final PdfExternalSigningResult prepared =
          await PdfExternalSigning.preparePdf(
        inputBytes: initialPdfBytes,
        fieldName: 'AssinaturaGovBr_2',
        pageNumber: 1,
        bounds: PDRectangle(50, 250, 250, 300),
        signature: PDSignature(),
      );

      final Uint8List digestBytes = _computeByteRangeDigest(
        prepared.preparedPdfBytes,
        prepared.byteRange,
      );

      final Uint8List pkcs7 = PdfCmsSigner.signDetachedSha256RsaFromPem(
        contentDigest: digestBytes,
        privateKeyPem: citizenKeyPem,
        certificatePem: citizenCertPem,
        chainPem: <String>[govRootCertPem],
      );

      final Uint8List finalBytes = PdfExternalSigning.embedSignature(
        preparedPdfBytes: prepared.preparedPdfBytes,
        pkcs7Bytes: pkcs7,
      );

      final File file = File('test/tmp/out_scenario3_multi.pdf');
      await file.writeAsBytes(finalBytes);

      final PdfSignatureValidator validator = PdfSignatureValidator();
      final PdfSignatureValidationReport report =
          await validator.validateAllSignatures(finalBytes);
      expect(report.signatures.length, 2);
    });
  });
}

Future<void> _exportChainAsP7b(List<Uint8List> certsDer, String filePath) async {
  final ASN1Sequence certsSet = ASN1Sequence(tag: 0xA0);
  for (final Uint8List der in certsDer) {
    final ASN1Parser certParser = ASN1Parser(der);
    certsSet.add(certParser.nextObject());
  }

  final ASN1Sequence signedData = ASN1Sequence();
  signedData.add(ASN1Integer(BigInt.from(1)));
  signedData.add(ASN1Set());

  final ASN1Sequence encapContent = ASN1Sequence();
  encapContent.add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.7.1'));
  signedData.add(encapContent);

  signedData.add(certsSet);
  signedData.add(ASN1Set());

  final ASN1Sequence contentInfo = ASN1Sequence();
  contentInfo.add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.7.2'));

  final ASN1Sequence content0 = ASN1Sequence(tag: 0xA0);
  content0.add(signedData);
  contentInfo.add(content0);

  final File file = File(filePath);
  if (!await file.parent.exists()) {
    await file.parent.create(recursive: true);
  }
  await file.writeAsBytes(contentInfo.encodedBytes);
}

String _bytesToHex(Uint8List? bytes) {
  if (bytes == null) return 'null';
  return hex.encode(bytes);
}

ASN1Sequence? _getExtensions(ASN1Sequence tbs) {
  for (final el in tbs.elements) {
    if (el.tag == 0xA3) {
      final ASN1Parser extSeqParser = ASN1Parser(el.valueBytes());
      return extSeqParser.nextObject() as ASN1Sequence;
    }
  }
  return null;
}

Uint8List? _getExtensionValue(ASN1Sequence? extensions, String oidStr) {
  if (extensions == null) return null;
  for (final el in extensions.elements) {
    if (el is ASN1Sequence) {
      final ASN1ObjectIdentifier oid = el.elements[0] as ASN1ObjectIdentifier;
      if (oid.identifier == oidStr) {
        final ASN1Object valueObj = el.elements.last;
        if (valueObj is ASN1OctetString) {
          return valueObj.valueBytes();
        }
      }
    }
  }
  return null;
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

void _validatePkcs7Chain(Uint8List pkcs7, int expectedCertCount) {
  final ASN1Parser parser = ASN1Parser(pkcs7);
  final ASN1Sequence topSeq = parser.nextObject() as ASN1Sequence;

  final ASN1Object contentTagged = topSeq.elements[1];
  final ASN1Parser signedDataParser = ASN1Parser(contentTagged.valueBytes());
  final ASN1Sequence signedDataSeq =
      signedDataParser.nextObject() as ASN1Sequence;

  ASN1Object? certsTagged;
  for (final el in signedDataSeq.elements) {
    if (el.tag == 0xA0) {
      certsTagged = el;
      break;
    }
  }

  if (expectedCertCount == 0) {
    return;
  }

  expect(certsTagged, isNotNull,
      reason: 'Certificates set [0] not found in SignedData');

  final ASN1Parser certsParser = ASN1Parser(certsTagged!.valueBytes());
  int count = 0;
  while (certsParser.hasNext()) {
    certsParser.nextObject();
    count++;
  }
  expect(count, equals(expectedCertCount),
      reason: 'Chain should contain $expectedCertCount certs, found $count');

  _validateChainLinkage(certsTagged);
}

void _validateChainLinkage(ASN1Object certsTagged) {
  final ASN1Parser certsParser = ASN1Parser(certsTagged.valueBytes());
  final List<_CertInfo> certs = <_CertInfo>[];

  while (certsParser.hasNext()) {
    final ASN1Sequence cert = certsParser.nextObject() as ASN1Sequence;
    final ASN1Sequence tbs = cert.elements[0] as ASN1Sequence;

    final Uint8List issuerBytes = tbs.elements[3].encodedBytes;
    final Uint8List subjectBytes = tbs.elements[5].encodedBytes;

    String? ski;
    String? aki;

    for (final el in tbs.elements) {
      if (el.tag == 0xA3) {
        final ASN1Parser extSeqParser = ASN1Parser(el.valueBytes());
        final ASN1Sequence extSeq = extSeqParser.nextObject() as ASN1Sequence;

        for (final ext in extSeq.elements) {
          if (ext is ASN1Sequence) {
            final ASN1ObjectIdentifier oid =
                ext.elements[0] as ASN1ObjectIdentifier;
            final String oidStr = oid.identifier ?? '';

            final ASN1Object valueOctet = ext.elements.last;
            if (valueOctet is! ASN1OctetString) continue;

            if (oidStr == '2.5.29.14') {
              final ASN1Parser skiParser = ASN1Parser(valueOctet.valueBytes());
              final ASN1Object skiOctet = skiParser.nextObject();
              ski = _bytesToHex(Uint8List.fromList(skiOctet.valueBytes()));
            }
            if (oidStr == '2.5.29.35') {
              final ASN1Parser akiParser = ASN1Parser(valueOctet.valueBytes());
              final ASN1Sequence akiSeq =
                  akiParser.nextObject() as ASN1Sequence;
              for (final akiEl in akiSeq.elements) {
                if (akiEl.tag == 0x80) {
                  aki = _bytesToHex(Uint8List.fromList(akiEl.valueBytes()));
                  break;
                }
              }
            }
          }
        }
        break;
      }
    }

    certs.add(_CertInfo(
      subject: _bytesToHex(subjectBytes),
      issuer: _bytesToHex(issuerBytes),
      ski: ski,
      aki: aki,
    ));
  }

  int nonSelfSignedCount = 0;
  int linkedCount = 0;

  for (final _CertInfo cert in certs) {
    final bool isSelfSigned = cert.subject == cert.issuer;
    if (!isSelfSigned) {
      nonSelfSignedCount++;
      if (cert.aki != null) {
        final List<_CertInfo> issuerCert =
            certs.where((c) => c.ski == cert.aki).toList();
        expect(issuerCert, isNotEmpty,
            reason: 'Cert with AKI=${cert.aki} has no matching issuer SKI');
        linkedCount++;
      }
    }
  }

  if (nonSelfSignedCount > 0) {
    expect(linkedCount, equals(nonSelfSignedCount),
        reason: 'Not all non-self-signed certs have valid AKI linkage');
  }
}

void _validateChainLinkageFromDerList(List<Uint8List> certsDer) {
  final List<_CertInfo> certs = <_CertInfo>[];

  for (final Uint8List certDer in certsDer) {
    final ASN1Sequence cert =
        ASN1Parser(certDer).nextObject() as ASN1Sequence;
    final ASN1Sequence tbs = cert.elements[0] as ASN1Sequence;

    final Uint8List issuerBytes = tbs.elements[3].encodedBytes;
    final Uint8List subjectBytes = tbs.elements[5].encodedBytes;

    String? ski;
    String? aki;

    for (final el in tbs.elements) {
      if (el.tag == 0xA3) {
        final ASN1Parser extSeqParser = ASN1Parser(el.valueBytes());
        final ASN1Sequence extSeq = extSeqParser.nextObject() as ASN1Sequence;

        for (final ext in extSeq.elements) {
          if (ext is ASN1Sequence) {
            final ASN1ObjectIdentifier oid =
                ext.elements[0] as ASN1ObjectIdentifier;
            final String oidStr = oid.identifier ?? '';

            final ASN1Object valueOctet = ext.elements.last;
            if (valueOctet is! ASN1OctetString) continue;

            if (oidStr == '2.5.29.14') {
              final ASN1Parser skiParser = ASN1Parser(valueOctet.valueBytes());
              final ASN1Object skiOctet = skiParser.nextObject();
              ski = _bytesToHex(Uint8List.fromList(skiOctet.valueBytes()));
            }
            if (oidStr == '2.5.29.35') {
              final ASN1Parser akiParser = ASN1Parser(valueOctet.valueBytes());
              final ASN1Sequence akiSeq =
                  akiParser.nextObject() as ASN1Sequence;
              for (final akiEl in akiSeq.elements) {
                if (akiEl.tag == 0x80) {
                  aki = _bytesToHex(Uint8List.fromList(akiEl.valueBytes()));
                  break;
                }
              }
            }
          }
        }
        break;
      }
    }

    certs.add(_CertInfo(
      subject: _bytesToHex(subjectBytes),
      issuer: _bytesToHex(issuerBytes),
      ski: ski,
      aki: aki,
    ));
  }

  int nonSelfSignedCount = 0;
  int linkedCount = 0;

  for (final _CertInfo cert in certs) {
    final bool isSelfSigned = cert.subject == cert.issuer;
    if (!isSelfSigned) {
      nonSelfSignedCount++;
      if (cert.aki != null) {
        final List<_CertInfo> issuerCert =
            certs.where((c) => c.ski == cert.aki).toList();
        expect(issuerCert, isNotEmpty,
            reason: 'Cert with AKI=${cert.aki} has no matching issuer SKI');
        linkedCount++;
      }
    }
  }

  if (nonSelfSignedCount > 0) {
    expect(linkedCount, equals(nonSelfSignedCount),
        reason: 'Not all non-self-signed certs have valid AKI linkage');
  }
}

class _CertInfo {
  final String subject;
  final String issuer;
  final String? ski;
  final String? aki;
  const _CertInfo({
    required this.subject,
    required this.issuer,
    this.ski,
    this.aki,
  });
}
