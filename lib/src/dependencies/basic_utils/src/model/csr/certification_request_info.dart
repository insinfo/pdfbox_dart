import 'certificate_signing_request_extensions.dart';
import 'subject_public_key_info.dart';

class CertificationRequestInfo {
  /// The version
  int? version;

  /// The subject data of the certificate singing request
  Map<String, String>? subject;

  /// The public key information
  SubjectPublicKeyInfo? publicKeyInfo;

  CertificateSigningRequestExtensions? extensions;

  CertificationRequestInfo({
    this.subject,
    this.version,
    this.publicKeyInfo,
    this.extensions,
  });

  /*
   * Json to CertificationRequestInfo object
   */
  factory CertificationRequestInfo.fromJson(Map<String, dynamic> json) {
    return CertificationRequestInfo(
      subject: (json['subject'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      version: json['version'] as int?,
      publicKeyInfo: json['publicKeyInfo'] == null
          ? null
          : SubjectPublicKeyInfo.fromJson(
              json['publicKeyInfo'] as Map<String, dynamic>),
      extensions: json['extensions'] == null
          ? null
          : CertificateSigningRequestExtensions.fromJson(
              json['extensions'] as Map<String, dynamic>),
    );
  }

  /*
   * CertificationRequestInfo object to json
   */
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('version', version);
    writeNotNull('subject', subject);
    writeNotNull('publicKeyInfo', publicKeyInfo?.toJson());
    writeNotNull('extensions', extensions?.toJson());
    return val;
  }
}