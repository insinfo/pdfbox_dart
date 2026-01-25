import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../cos/cos_array.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import '../cos/cos_stream.dart';
import '../pdmodel/interactive/form/pd_acro_form.dart';
import '../pdmodel/interactive/form/pd_field.dart';
import '../pdmodel/interactive/form/pd_signature_field.dart';
import '../pdmodel/interactive/digitalsignature/pd_signature.dart';
import '../pdmodel/pd_document.dart';
import 'kms/revocation_data_client.dart';
import 'pdf_signature_validator.dart';
import '../../crypto/x509/core/x509_certificates.dart';
import '../../crypto/x509/core/x509_utils.dart';

/// Manages Long Term Validation (LTV) features for PDF Documents.
///
/// Enables adding DSS (Document Security Store) and VRI (Validation Related Information)
/// to ensure signatures remain valid even if certificates expire or revocation servers go offline.
class PdfLtvManager {
  PdfLtvManager(this.document);

  final PDDocument document;

  /// Adds LTV information (DSS/VRI) for all signatures in the document.
  ///
  /// [pdfBytes]: The raw bytes of the PDF document (required to parse existing signatures).
  /// [trustedRoots]: List of trusted root certificates to validate chains.
  /// [addVri]: Whether to add VRI dictionaries for each signature (recommended for PAdES-LTV).
  Future<void> enableLtv(
    Uint8List pdfBytes, {
    List<X509Certificate>? trustedRoots,
    bool addVri = true,
  }) async {
    final PdfSignatureValidator validator = PdfSignatureValidator();
    final PdfSignatureValidationReport report =
        await validator.validateAllSignatures(
      pdfBytes,
      fetchCrls: false,
    );

    final List<List<int>> allCrls = <List<int>>[];
    final List<List<int>> allOcsps = <List<int>>[];
    final List<List<int>> allCerts = <List<int>>[];

    final COSDictionary catalog = document.documentCatalog.cosObject;

    for (final PdfSignatureValidationItem sig in report.signatures) {
      if (!sig.validation.cmsSignatureValid) continue;

      final List<X509Certificate> chain = <X509Certificate>[];
      final List<Uint8List> chainBytes = <Uint8List>[];

      for (final String pem in sig.validation.certsPem) {
        try {
          final Uint8List der = X509Utils.pemToDer(pem);
          chainBytes.add(der);
          chain.add(X509Utils.parsePemCertificate(pem));
        } catch (_) {
          // Keep raw bytes for DSS even if parsing fails.
        }
      }

      for (final Uint8List bytes in chainBytes) {
        allCerts.add(bytes);
      }

      final List<List<int>> sigCrls = <List<int>>[];
      final List<List<int>> sigOcsps = <List<int>>[];

      for (int i = 0; i < chain.length; i++) {
        final X509Certificate cert = chain[i];

        X509Certificate? issuer;
        if (trustedRoots != null) {
          issuer = X509Utils.findIssuer(cert, trustedRoots);
        }
        issuer ??= (i + 1 < chain.length)
            ? X509Utils.findIssuer(cert, chain)
            : null;

        if (issuer != null) {
          final List<int>? ocspBytes =
              await RevocationDataClient.fetchOcspResponseBytes(cert, issuer);
          if (ocspBytes != null) {
            sigOcsps.add(ocspBytes);
            allOcsps.add(ocspBytes);
          }
        }

        final List<List<int>> fetchedCrls =
            await RevocationDataClient.fetchCrls(cert);
        for (final List<int> crl in fetchedCrls) {
          sigCrls.add(crl);
          allCrls.add(crl);
        }
      }

      if (addVri) {
        _addVri(catalog, sig, sigCrls, sigOcsps, chain);
      }
    }

    _updateDss(catalog, allCrls, allOcsps, allCerts);
  }

  void _addVri(
    COSDictionary catalog,
    PdfSignatureValidationItem sig,
    List<List<int>> crls,
    List<List<int>> ocsps,
    List<X509Certificate> chain,
  ) {
    final COSDictionary? sigDict = _findSignatureDictionary(sig.fieldName);
    if (sigDict == null) {
      return;
    }

    final PDSignature signature = PDSignature(sigDict);
    final Uint8List signatureBytes = signature.getContents();
    if (signatureBytes.isEmpty) {
      return;
    }

    final String vriKey = sha1.convert(signatureBytes).toString().toUpperCase();
    final COSDictionary vriDict = COSDictionary();

    if (crls.isNotEmpty) {
      final COSArray crlArr = COSArray();
      for (final List<int> c in crls) {
        _addToArrayAsStream(crlArr, c);
      }
      vriDict[COSName.get('CRL')] = crlArr;
    }
    if (ocsps.isNotEmpty) {
      final COSArray ocspArr = COSArray();
      for (final List<int> o in ocsps) {
        _addToArrayAsStream(ocspArr, o);
      }
      vriDict[COSName.get('OCSP')] = ocspArr;
    }
    if (chain.isNotEmpty) {
      final COSArray certArr = COSArray();
      for (final X509Certificate c in chain) {
        final List<int>? der = c.c?.getDerEncoded();
        if (der != null) {
          _addToArrayAsStream(certArr, der);
        }
      }
      vriDict[COSName.get('Cert')] = certArr;
    }

    _addToDssVri(catalog, vriKey, vriDict);
  }

  COSDictionary? _findSignatureDictionary(String fieldName) {
    final PDAcroForm? acroForm = document.documentCatalog.acroForm;
    if (acroForm == null) {
      return null;
    }

    final PDField? field = acroForm.getField(fieldName);
    if (field is PDSignatureField) {
      final PDSignature? sig = field.signature;
      if (sig != null) {
        return sig.cosObject;
      }
      return field.cosObject.getCOSDictionary(COSName.v);
    }

    for (final PDField candidate in acroForm.fieldTree) {
      if (candidate is! PDSignatureField) {
        continue;
      }
      if (candidate.fullyQualifiedName == fieldName ||
          candidate.partialName == fieldName) {
        final PDSignature? sig = candidate.signature;
        if (sig != null) {
          return sig.cosObject;
        }
        return candidate.cosObject.getCOSDictionary(COSName.v);
      }
    }

    return null;
  }

  void _updateDss(
    COSDictionary catalog,
    List<List<int>> crls,
    List<List<int>> ocsps,
    List<List<int>> certs,
  ) {
    COSDictionary? dss = catalog.getCOSDictionary(COSName.get('DSS'));
    dss ??= COSDictionary();
    catalog[COSName.get('DSS')] = dss;

    if (certs.isNotEmpty) {
      _mergeArray(dss, COSName.get('Certs'), certs);
    }
    if (crls.isNotEmpty) {
      _mergeArray(dss, COSName.get('CRLs'), crls);
    }
    if (ocsps.isNotEmpty) {
      _mergeArray(dss, COSName.get('OCSPs'), ocsps);
    }
  }

  void _addToDssVri(COSDictionary catalog, String key, COSDictionary vriDict) {
    _updateDss(catalog, <List<int>>[], <List<int>>[], <List<int>>[]);
    final COSDictionary? dss = catalog.getCOSDictionary(COSName.get('DSS'));
    if (dss == null) {
      return;
    }

    COSDictionary? vri = dss.getCOSDictionary(COSName.get('VRI'));
    vri ??= COSDictionary();
    dss[COSName.get('VRI')] = vri;

    vri[COSName.get(key)] = vriDict;
  }

  void _mergeArray(COSDictionary dict, COSName key, List<List<int>> newItems) {
    COSArray? arr = dict.getCOSArray(key);
    arr ??= COSArray();
    dict[key] = arr;

    for (final List<int> item in newItems) {
      _addToArrayAsStream(arr, item);
    }
  }

  void _addToArrayAsStream(COSArray arr, List<int> bytes) {
    final COSStream stream = COSStream();
    stream.data = Uint8List.fromList(bytes);
    arr.addObject(stream);
  }

}

