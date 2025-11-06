// ignore_for_file: deprecated_member_use_from_same_package

import 'certificate_signing_request_extensions.dart';
import 'certification_request_info.dart';
import 'subject_public_key_info.dart';

class CertificateSigningRequestData {
  /// The certificationRequestInfo
  CertificationRequestInfo? certificationRequestInfo;

  /// The version
  @Deprecated('Use certificationRequestInfo.version instead')
  int? version;

  /// The subject data of the certificate singing request
  @Deprecated('Use certificationRequestInfo.subject instead')
  Map<String, String>? subject;

  /// The public key information
  @Deprecated('Use certificationRequestInfo.publicKeyInfo instead')
  SubjectPublicKeyInfo? publicKeyInfo;

  /// The signature algorithm
  String? signatureAlgorithm;

  /// The readable name of the signature algorithm
  String? signatureAlgorithmReadableName;

  /// The salt length if algorithm is rsaPSS
  int? saltLength;

  /// The digest used for PSS signature
  String? pssDigest;

  /// The signature
  String? signature;

  /// The plain PEM string
  String? plain;

  /// The extension
  @Deprecated('Use certificationRequestInfo.extensions instead')
  CertificateSigningRequestExtensions? extensions;

  /// The certificationRequestInfo sequence as base64
  String? certificationRequestInfoSeq;

  CertificateSigningRequestData({
    this.subject,
    this.version,
    this.signature,
    this.signatureAlgorithm,
    this.signatureAlgorithmReadableName,
    this.publicKeyInfo,
    this.plain,
    this.extensions,
    this.certificationRequestInfoSeq,
    this.certificationRequestInfo,
    this.saltLength,
    this.pssDigest,
  });

  /*
   * Json to CertificateSigningRequestData object
   */
  factory CertificateSigningRequestData.fromJson(Map<String, dynamic> json) {
    return CertificateSigningRequestData(
      subject: (json['subject'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      version: json['version'] as int?,
      signature: json['signature'] as String?,
      signatureAlgorithm: json['signatureAlgorithm'] as String?,
      signatureAlgorithmReadableName:
          json['signatureAlgorithmReadableName'] as String?,
      publicKeyInfo: json['publicKeyInfo'] == null
          ? null
          : SubjectPublicKeyInfo.fromJson(
              json['publicKeyInfo'] as Map<String, dynamic>),
      plain: json['plain'] as String?,
      extensions: json['extensions'] == null
          ? null
          : CertificateSigningRequestExtensions.fromJson(
              json['extensions'] as Map<String, dynamic>),
      certificationRequestInfoSeq:
          json['certificationRequestInfoSeq'] as String?,
      certificationRequestInfo: json['certificationRequestInfo'] == null
          ? null
          : CertificationRequestInfo.fromJson(
              json['certificationRequestInfo'] as Map<String, dynamic>),
      // Os campos saltLength e pssDigest não estavam no código gerado fornecido,
      // então são inicializados como nulos.
      saltLength: json['saltLength'] as int?,
      pssDigest: json['pssDigest'] as String?,
    );
  }

  /*
   * CertificateSigningRequestData object to json
   */
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull(
        'certificationRequestInfo', certificationRequestInfo?.toJson());
    writeNotNull('version', version);
    writeNotNull('subject', subject);
    writeNotNull('publicKeyInfo', publicKeyInfo?.toJson());
    writeNotNull('signatureAlgorithm', signatureAlgorithm);
    writeNotNull(
        'signatureAlgorithmReadableName', signatureAlgorithmReadableName);
    writeNotNull('saltLength', saltLength); // Adicionado para consistência
    writeNotNull('pssDigest', pssDigest); // Adicionado para consistência
    writeNotNull('signature', signature);
    writeNotNull('plain', plain);
    writeNotNull('extensions', extensions?.toJson());
    writeNotNull(
        'certificationRequestInfoSeq', certificationRequestInfoSeq);
    return val;
  }
}