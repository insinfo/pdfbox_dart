import 'dart:typed_data';

import '../pdmodel/interactive/digitalsignature/pd_signature.dart';
import '../pdmodel/interactive/form/pd_signature_field.dart';
import '../pdmodel/pd_document.dart';
import '../../io/stream_reader.dart';
import 'enum.dart';
import 'pdf_external_signer.dart';
import 'pdf_ltv_manager.dart';
import 'pdf_pkcs_certificate.dart';
import 'time_stamp_server/time_stamp_server.dart';
import '../../crypto/x509/core/x509_certificates.dart';

/// Represents a digital signature configuration for a PDF document.
class PdfSignature {
  PdfSignature({
    String? signedName,
    String? locationInfo,
    String? reason,
    String? contactInfo,
    List<PdfCertificationFlags>? documentPermissions,
    CryptographicStandard cryptographicStandard = CryptographicStandard.cms,
    DigestAlgorithm digestAlgorithm = DigestAlgorithm.sha256,
    PdfPKCSCertificate? certificate,
    TimestampServer? timestampServer,
    DateTime? signedDate,
  }) {
    _helper = PdfSignatureHelper(this);
    if (documentPermissions != null && documentPermissions.isNotEmpty) {
      _helper.certificated = true;
    }
    _init(
      signedName,
      locationInfo,
      reason,
      contactInfo,
      documentPermissions,
      cryptographicStandard,
      digestAlgorithm,
      certificate,
      signedDate,
      timestampServer,
    );
  }

  /// Configures this signature as DocMDP (certification signature).
  ///
  /// Returns false if the document already has signatures.
  bool configureDocMdpForFirstSignature(
    PDDocument document, {
    int permissionP = 2,
  }) {
    if (_documentHasSignatures(document)) {
      return false;
    }

    switch (permissionP) {
      case 1:
        documentPermissions = <PdfCertificationFlags>[
          PdfCertificationFlags.forbidChanges
        ];
        break;
      case 2:
        documentPermissions = <PdfCertificationFlags>[
          PdfCertificationFlags.allowFormFill
        ];
        break;
      case 3:
        documentPermissions = <PdfCertificationFlags>[
          PdfCertificationFlags.allowComments
        ];
        break;
      default:
        throw RangeError.range(permissionP, 1, 3, 'permissionP');
    }

    PdfSignatureHelper.getHelper(this).certificated = true;
    return true;
  }

  late PdfSignatureHelper _helper;
  List<List<int>>? _externalRootCert;

  /// Gets or sets the permission for certificated document.
  List<PdfCertificationFlags> documentPermissions = <PdfCertificationFlags>[
    PdfCertificationFlags.forbidChanges,
  ];

  /// Gets or sets reason of signing.
  String? reason;

  /// Gets or sets the physical location of the signing.
  String? locationInfo;

  /// Gets or sets the signed name.
  String? signedName;

  /// Gets or sets the signed date.
  DateTime? get signedDate => _helper.dateOfSign;

  set signedDate(DateTime? value) {
    _helper.dateOfSign = value;
  }

  /// Gets or sets cryptographic standard.
  late CryptographicStandard cryptographicStandard;

  /// Gets or sets digestion algorithm.
  late DigestAlgorithm digestAlgorithm;

  /// Gets or sets information provided by the signer.
  String? contactInfo;

  /// Gets or sets the certificate.
  PdfPKCSCertificate? certificate;

  /// Gets or sets time stamping server.
  TimestampServer? timestampServer;

  void _init(
    String? signedName,
    String? locationInfo,
    String? reason,
    String? contactInfo,
    List<PdfCertificationFlags>? documentPermissions,
    CryptographicStandard cryptographicStandard,
    DigestAlgorithm digestAlgorithm,
    PdfPKCSCertificate? pdfCertificate,
    DateTime? signedDate,
    TimestampServer? timestampServer,
  ) {
    this.cryptographicStandard = cryptographicStandard;
    this.digestAlgorithm = digestAlgorithm;
    if (signedName != null) {
      this.signedName = signedName;
    }
    if (locationInfo != null) {
      this.locationInfo = locationInfo;
    }
    if (reason != null) {
      this.reason = reason;
    }
    if (contactInfo != null) {
      this.contactInfo = contactInfo;
    }
    if (documentPermissions != null && documentPermissions.isNotEmpty) {
      this.documentPermissions = documentPermissions;
    }
    if (pdfCertificate != null) {
      certificate = pdfCertificate;
    }
    if (signedDate != null) {
      this.signedDate = signedDate;
    }
    if (timestampServer != null) {
      this.timestampServer = timestampServer;
    }
  }

  /// Returns a PDSignature configured with the stored metadata.
  PDSignature toPdSignature() {
    final PDSignature sig = PDSignature();
    if (signedName != null) {
      sig.setName(signedName);
    }
    if (locationInfo != null) {
      sig.setLocation(locationInfo);
    }
    if (reason != null) {
      sig.setReason(reason);
    }
    if (contactInfo != null) {
      sig.setContactInfo(contactInfo);
    }
    sig.setSignDate(signedDate);
    return sig;
  }

  /// Adds external signer for signature.
  void addExternalSigner(
    IPdfExternalSigner signer,
    List<List<int>> publicCertificatesData,
  ) {
    _helper.externalSigner = signer;
    _externalRootCert = publicCertificatesData;
    if (_externalRootCert != null) {
      final X509CertificateParser parser = X509CertificateParser();
      _helper.externalChain = <X509Certificate?>[];
      for (final List<int> certRawData in _externalRootCert!) {
        final X509Certificate? cert =
            parser.readCertificate(PdfStreamReader(certRawData));
        if (cert != null) {
          _helper.externalChain!.add(cert);
        }
      }
    }
  }

  /// Creates long-term validation (DSS/VRI) for the document.
  Future<bool> createLongTermValidity({
    required PDDocument document,
    required Uint8List pdfBytes,
    List<List<int>>? publicCertificatesData,
    RevocationType type = RevocationType.ocspAndCrl,
    bool includePublicCertificates = false,
  }) async {
    final PdfLtvManager manager = PdfLtvManager(document);
    await manager.enableLtv(
      pdfBytes,
      addVri: true,
    );
    return true;
  }

  bool _documentHasSignatures(PDDocument document) {
    final acroForm = document.documentCatalog.acroForm;
    if (acroForm == null) {
      return false;
    }
    for (final field in acroForm.fieldTree) {
      if (field is PDSignatureField && field.signature != null) {
        return true;
      }
    }
    return false;
  }
}

/// [PdfSignature] helper.
class PdfSignatureHelper {
  PdfSignatureHelper(this.base);

  PdfSignature base;

  static PdfSignatureHelper getHelper(PdfSignature signature) {
    return signature._helper;
  }

  bool certificated = false;
  DateTime? dateOfSign;
  IPdfExternalSigner? externalSigner;
  List<X509Certificate?>? externalChain;
}

/// Specifies the type of revocation to be considered during the LTV enable process.
enum RevocationType {
  ocsp,
  crl,
  ocspAndCrl,
  ocspOrCrl,
}

