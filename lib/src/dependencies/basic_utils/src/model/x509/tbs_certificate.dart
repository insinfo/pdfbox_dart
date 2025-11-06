import '../csr/subject_public_key_info.dart';
import 'x509_certificate_data_extensions.dart';
import 'x509_certificate_validity.dart';

///
/// Model that represents the data of a TbsCertificate
///
class TbsCertificate {
  /// The version of the certificate
  int version;

  /// The serialNumber of the certificate
  BigInt serialNumber;

  /// The signatureAlgorithm of the certificate
  String signatureAlgorithm;

  /// The readable name of the signatureAlgorithm of the certificate
  String? signatureAlgorithmReadableName;

  /// The issuer data of the certificate
  Map<String, String?> issuer;

  /// The validity of the certificate
  X509CertificateValidity validity;

  /// The subject data of the certificate
  Map<String, String?> subject;

  /// The public key data from the certificate
  SubjectPublicKeyInfo subjectPublicKeyInfo;

  /// The certificate extensions
  X509CertificateDataExtensions? extensions;

  TbsCertificate({
    required this.version,
    required this.serialNumber,
    required this.issuer,
    required this.validity,
    required this.subject,
    required this.subjectPublicKeyInfo,
    required this.signatureAlgorithm,
    required this.signatureAlgorithmReadableName,
    this.extensions,
  });

  /*
   * Json to TbsCertificate object
   */
  factory TbsCertificate.fromJson(Map<String, dynamic> json) {
    return TbsCertificate(
      version: json['version'] as int,
      serialNumber: BigInt.parse(json['serialNumber'] as String),
      issuer: Map<String, String?>.from(json['issuer'] as Map),
      validity: X509CertificateValidity.fromJson(
          json['validity'] as Map<String, dynamic>),
      subject: Map<String, String?>.from(json['subject'] as Map),
      subjectPublicKeyInfo: SubjectPublicKeyInfo.fromJson(
          json['subjectPublicKeyInfo'] as Map<String, dynamic>),
      signatureAlgorithm: json['signatureAlgorithm'] as String,
      signatureAlgorithmReadableName:
          json['signatureAlgorithmReadableName'] as String?,
      extensions: json['extensions'] == null
          ? null
          : X509CertificateDataExtensions.fromJson(
              json['extensions'] as Map<String, dynamic>),
    );
  }

  /*
   * TbsCertificate object to json
   */
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{
      'version': version,
      'serialNumber': serialNumber.toString(),
      'signatureAlgorithm': signatureAlgorithm,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull(
        'signatureAlgorithmReadableName', signatureAlgorithmReadableName);
    val['issuer'] = issuer;
    val['validity'] = validity.toJson();
    val['subject'] = subject;
    val['subjectPublicKeyInfo'] = subjectPublicKeyInfo.toJson();
    writeNotNull('extensions', extensions?.toJson());
    return val;
  }
}