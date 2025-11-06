import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pdfbox_dart/basic_utils.dart';

class PdfSignatureValidationResult {
  final bool cmsSignatureValid; // verificação RSA do CMS
  final bool byteRangeDigestOk; // SHA-256(ByteRange) == messageDigest
  final bool documentIntact; // resumo: cmsSignatureValid && byteRangeDigestOk
  final List<String> certsPem; // ordem: [assinante, ...cadeia]

  PdfSignatureValidationResult({
    required this.cmsSignatureValid,
    required this.byteRangeDigestOk,
    required this.documentIntact,
    required this.certsPem,
  });
}

class _CmsParsed {
  Uint8List? messageDigest;
  Uint8List? signedAttrsEncoded; // DER do SET OF SignedAttributes
  Uint8List? signedAttrsImplicit; // bytes conforme armazenado no CMS (tag [0])
  Uint8List? signedAttrsValue; // apenas conteúdo do SET OF
  Uint8List? signature; // OCTET STRING
  RSAPublicKey? signerPublicKey;
  List<String> certsPem = [];
  List<String> attributeOids = [];
}

class PdfSignatureValidation {
  static const int _derSetTag = 0x31;

  PdfSignatureValidationResult validatePdfSignature(Uint8List pdfBytes,
      {bool verbose = false, String? userCrtPem}) {
    // 1) Localiza assinatura usando a lib dart_pdf para obter ByteRange/Contents
    final byteRange = _extractByteRange(pdfBytes);
    final contentsHex = _extractContentsHex(pdfBytes);
    if (byteRange == null || contentsHex == null) {
      return PdfSignatureValidationResult(
        cmsSignatureValid: false,
        byteRangeDigestOk: false,
        documentIntact: false,
        certsPem: const [],
      );
    }

    // 2) Extrai bytes assinados (fora da janela do /Contents)
    final signedPortion = _collectSignedPortions(pdfBytes, byteRange);

    // 3) Decodifica CMS (Contents) — remover padding zero do fim
    var cmsBytes = _hexToBytes(contentsHex);
    cmsBytes = _trimDerPadding(cmsBytes);

    // 4) Parser ASN.1 do CMS
    final cms = _parseCms(cmsBytes);

    // 5) Obtém digest SHA-256 dos bytes assinados e confere com messageDigest
    final actualDigest =
        CryptoUtils.getHash(signedPortion, algorithmName: 'SHA-256');
    final actualDigestBytes = _hexToBytes(actualDigest);
    final digestMatches = _constantTimeEquals(
        actualDigestBytes, cms.messageDigest ?? Uint8List(0));

    // 6) Verifica assinatura RSA sobre DER de signedAttrs
    bool sigValid = false;
    String? publicKeySource;
    try {
      // Se o CMS não trouxer o certificado, tenta usar user.crt (mesma pasta) como fallback
      RSAPublicKey? pub = cms.signerPublicKey;
      if (pub != null) {
        publicKeySource = 'CMS';
      } else if (userCrtPem != null) {
        final pem = userCrtPem;
        final x = X509Utils.x509CertificateFromPem(pem);
        final spki = _hexToBytes(x.tbsCertificate!.subjectPublicKeyInfo.bytes!);
        pub = CryptoUtils.rsaPublicKeyFromDERBytes(spki);
        publicKeySource = 'user.crt';
      }
      if (pub != null &&
          cms.signedAttrsEncoded != null &&
          cms.signature != null) {
        sigValid = CryptoUtils.rsaVerify(
          pub,
          cms.signedAttrsEncoded!,
          cms.signature!,
          algorithm: 'SHA-256/RSA',
        );
      }
    } catch (_) {
      sigValid = false;
    }

    if (verbose) {
      final expected = cms.messageDigest;
      if (cms.attributeOids.isNotEmpty) {
        print('Atributos CMS         : ${cms.attributeOids.join(', ')}');
      }
      print('Origem chave pública  : ${publicKeySource ?? 'indisponível'}');
      print(
          'messageDigest (CMS): ${expected != null ? _bytesToHex(expected) : 'n/a'}');
      print('digest calculado      : ${_bytesToHex(actualDigestBytes)}');
      print('Assinatura RSA ok     : $sigValid');
      print('Certificados no CMS   : ${cms.certsPem.length}');
      if (cms.signedAttrsImplicit != null) {
        print(
            'signedAttrs [0] hex   : ${_bytesToHex(cms.signedAttrsImplicit!)}');
      }
      if (cms.signedAttrsValue != null) {
        print('signedAttrs value hex : ${_bytesToHex(cms.signedAttrsValue!)}');
      }
      if (cms.signedAttrsEncoded != null) {
        print(
            'signedAttrs DER hex   : ${_bytesToHex(cms.signedAttrsEncoded!)}');
      }
      if (cms.signedAttrsEncoded != null) {
        try {
          final p2 = ASN1Parser(cms.signedAttrsEncoded!);
          final top = p2.nextObject();
          final tag = top.tag?.toRadixString(16) ?? '??';
          print('signedAttrs tag       : 0x$tag (${top.runtimeType})');
          if (top.valueBytes != null) {
            final inner = ASN1Parser(top.valueBytes!).nextObject();
            final innerTag = inner.tag?.toRadixString(16) ?? '??';
            int count = 0;
            if (inner is ASN1Set) {
              count = inner.elements?.length ?? 0;
            } else if (inner is ASN1Sequence) {
              count = inner.elements?.length ?? 0;
            }
            print(
                'signedAttrs inner     : ${inner.runtimeType} tag=0x$innerTag entries=$count');
          }
        } catch (_) {}
      }
    }

    return PdfSignatureValidationResult(
      cmsSignatureValid: sigValid,
      byteRangeDigestOk: digestMatches,
      documentIntact: digestMatches && sigValid,
      certsPem: cms.certsPem,
    );
  }

  _CmsParsed _parseCms(Uint8List cmsBytes) {
    final out = _CmsParsed();
    final p = ASN1Parser(cmsBytes);
    final top = p.nextObject() as ASN1Sequence; // ContentInfo
    final oi = top.elements!.elementAt(0)
        as ASN1ObjectIdentifier; // 1.2.840.113549.1.7.2
    if (oi.objectIdentifierAsString != '1.2.840.113549.1.7.2') {
      return out; // not signedData
    }
    final signedDataWrapper = top.elements!.elementAt(1); // [0]
    final sdSeq =
        ASN1Parser(signedDataWrapper.valueBytes).nextObject() as ASN1Sequence;

    // signedData: version, digestAlgorithms(SET), encapContentInfo(SEQ), [0]certs?, signerInfos(SET)
    var idx = 0;
    idx++; // version
    idx++; // digestAlgorithms
    // encapContentInfo — não utilizado aqui; apenas avançamos o índice
    idx++;
    // Optional certificates
    ASN1Object? certsObj;
    if (sdSeq.elements!.length > idx) {
      final t = sdSeq.elements!.elementAt(idx).tag ?? 0;
      if ((t & 0xE0) == 0xA0) {
        certsObj = sdSeq.elements!.elementAt(idx++);
      }
    }
    // signerInfos
    final signerInfosSet = sdSeq.elements!.elementAt(idx) as ASN1Set;
    final signerInfo = signerInfosSet.elements!.first as ASN1Sequence;

    // signerInfo: version, sid, digestAlgorithm, signedAttrs [0], signatureAlgorithm, signature, ...
    var siIdx = 0;
    siIdx++; // version
    final sid =
        signerInfo.elements!.elementAt(siIdx++); // issuerAndSerialNumber
    siIdx++; // digestAlgorithm
    final signedAttrs = signerInfo.elements!.elementAt(siIdx++); // [0]
    siIdx++; // signatureAlgorithm
    final sigOctet = signerInfo.elements!.elementAt(siIdx++) as ASN1OctetString;
    out.signature = sigOctet.valueBytes;
    // Importante: capítulo 5.4 do RFC 5652 — a assinatura é feita sobre a
    // codificação DER do SET OF SignedAttributes (sem o wrapper IMPLICIT [0]).
    out.signedAttrsImplicit = signedAttrs.encodedBytes;
    if (signedAttrs.valueBytes != null) {
      out.signedAttrsValue = Uint8List.fromList(signedAttrs.valueBytes!);
      out.signedAttrsEncoded = _encodeDerSet(out.signedAttrsValue!);
    } else {
      out.signedAttrsEncoded = signedAttrs.encodedBytes;
    }

    // Pega messageDigest dentro dos atributos assinados
    final attrSequences = <ASN1Sequence>[];
    try {
      final attrParser = ASN1Parser(signedAttrs.valueBytes);
      while (attrParser.hasNext()) {
        final obj = attrParser.nextObject();
        if (obj is ASN1Set && obj.elements != null) {
          for (final el in obj.elements!) {
            if (el is ASN1Sequence) {
              attrSequences.add(el);
            }
          }
        } else if (obj is ASN1Sequence) {
          attrSequences.add(obj);
        }
      }
    } catch (_) {}

    for (final attr in attrSequences) {
      if (attr.elements == null || attr.elements!.length < 2) {
        out.attributeOids.add('invalid:${attr.runtimeType}');
        continue;
      }
      final aOid = attr.elements!.elementAt(0);
      if (aOid is! ASN1ObjectIdentifier) {
        out.attributeOids.add('noOid:${aOid.runtimeType}');
        continue;
      }
      out.attributeOids.add(aOid.objectIdentifierAsString ?? '');
      if (aOid.objectIdentifierAsString == '1.2.840.113549.1.9.4') {
        final v = attr.elements!.elementAt(1);
        ASN1Set vset;
        if (v is ASN1Set) {
          vset = v;
        } else {
          vset = ASN1Set.fromBytes(v.encodedBytes!);
        }
        if (vset.elements != null && vset.elements!.isNotEmpty) {
          final value = vset.elements!.first;
          if (value is ASN1OctetString) {
            out.messageDigest = value.valueBytes;
          } else {
            final parsed = ASN1Parser(value.encodedBytes!).nextObject();
            if (parsed is ASN1OctetString) {
              out.messageDigest = parsed.valueBytes;
            }
          }
        }
      }
    }

    // Caso não seja possível reconstruir os atributos, mantemos a codificação
    // original do campo [0] como fallback já definido acima.

    // Extrai certificados para localizar o do assinante
    if (certsObj != null) {
      final container = ASN1Parser(certsObj.valueBytes).nextObject();
      Iterable<ASN1Object> children = const [];
      if (container is ASN1Set) {
        children = container.elements!;
      } else if (container is ASN1Sequence) {
        children = container.elements!;
      }
      for (final el in children) {
        if (el is ASN1Sequence &&
            el.elements != null &&
            el.elements!.length >= 3) {
          final e0 = el.elements!.elementAt(0);
          final e1 = el.elements!.elementAt(1);
          final e2 = el.elements!.elementAt(2);
          if (e0 is ASN1Sequence && e1 is ASN1Sequence && e2 is ASN1BitString) {
            try {
              final pem = X509Utils.encodeASN1ObjectToPem(
                  el, X509Utils.BEGIN_CERT, X509Utils.END_CERT);
              // sanity parse to ensure it's a real cert
              X509Utils.x509CertificateFromPem(pem);
              out.certsPem.add(pem);
            } catch (_) {
              // ignore non-certificate entries
            }
          }
        }
      }
    }

    // Determina o certificado do assinante via serialNumber do sid
    if (out.certsPem.isNotEmpty) {
      // sid: issuerAndSerialNumber => Sequence(..., Integer serial)
      final sidSeq = ASN1Sequence.fromBytes(sid.encodedBytes!);
      final serial = (sidSeq.elements!.elementAt(1) as ASN1Integer).integer!;
      for (final pem in out.certsPem) {
        final x = X509Utils.x509CertificateFromPem(pem);
        if (x.tbsCertificate!.serialNumber == serial) {
          // Extrai public key do sujeito
          final spkiHex = x.tbsCertificate!.subjectPublicKeyInfo.bytes!;
          final spki = _hexToBytes(spkiHex);
          final pub = CryptoUtils.rsaPublicKeyFromDERBytes(spki);
          out.signerPublicKey = pub;
          break;
        }
      }
    }

    return out;
  }

  List<int>? _extractByteRange(Uint8List pdfBytes) {
    final s = latin1.decode(pdfBytes, allowInvalid: true);
    final re = RegExp(r"/ByteRange\s*\[\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*\]");
    final m = re.firstMatch(s);
    if (m == null) return null;
    return [
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
    ];
  }

  String? _extractContentsHex(Uint8List pdfBytes) {
    final s = latin1.decode(pdfBytes, allowInvalid: true);
    final re = RegExp(r"/Contents\s*<([0-9A-Fa-f\s]+)>");
    final m = re.firstMatch(s);
    if (m == null) return null;
    return m.group(1)!.replaceAll(RegExp(r"\s+"), "");
  }

  Uint8List _collectSignedPortions(Uint8List pdf, List<int> br) {
    final a = br[0], b = br[1], c = br[2], d = br[3];
    final out = BytesBuilder();
    out.add(pdf.sublist(a, a + b));
    out.add(pdf.sublist(c, c + d));
    return out.toBytes();
  }

  Uint8List _hexToBytes(String hexStr) {
    final out = <int>[];
    for (int i = 0; i < hexStr.length; i += 2) {
      out.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(out);
  }

  Uint8List _encodeDerSet(Uint8List valueBytes) {
    final lenBytes = _encodeLengthBytes(valueBytes.length);
    final out = Uint8List(1 + lenBytes.length + valueBytes.length);
    out[0] = _derSetTag;
    out.setRange(1, 1 + lenBytes.length, lenBytes);
    out.setRange(1 + lenBytes.length, out.length, valueBytes);
    return out;
  }

  Uint8List _encodeLengthBytes(int length) {
    if (length <= 0x7F) {
      return Uint8List.fromList([length]);
    }
    final bytes = <int>[];
    var value = length;
    while (value > 0) {
      bytes.insert(0, value & 0xFF);
      value >>= 8;
    }
    return Uint8List.fromList([0x80 | bytes.length, ...bytes]);
  }

  Uint8List _trimDerPadding(Uint8List bytes) {
    // DER de ContentInfo começa com 0x30; corta zeros finais que foram pré-alocados no PDF
    int end = bytes.length;
    while (end > 0 && bytes[0] == 0x30 && bytes[end - 1] == 0x00) {
      end--;
    }
    return bytes.sublist(0, end);
  }

  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int r = 0;
    for (int i = 0; i < a.length; i++) {
      r |= a[i] ^ b[i];
    }
    return r == 0;
  }

  String _bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
