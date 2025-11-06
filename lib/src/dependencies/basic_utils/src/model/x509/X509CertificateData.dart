// ignore_for_file: deprecated_member_use_from_same_package

import '../../../src/model/x509/ExtendedKeyUsage.dart';
import '../../../src/model/x509/TbsCertificate.dart';
import '../../../src/model/x509/X509CertificateDataExtensions.dart';
import '../../../src/model/x509/X509CertificatePublicKeyData.dart';

import 'X509CertificateValidity.dart';

// Mapa de Enum para String (baseado no código gerado)
const _extendedKeyUsageEnumMap = {
  ExtendedKeyUsage.SERVER_AUTH: 'SERVER_AUTH',
  ExtendedKeyUsage.CLIENT_AUTH: 'CLIENT_AUTH',
  ExtendedKeyUsage.CODE_SIGNING: 'CODE_SIGNING',
  ExtendedKeyUsage.EMAIL_PROTECTION: 'EMAIL_PROTECTION',
  ExtendedKeyUsage.TIME_STAMPING: 'TIME_STAMPING',
  ExtendedKeyUsage.OCSP_SIGNING: 'OCSP_SIGNING',
  ExtendedKeyUsage.BIMI: 'BIMI',
};

// Helper manual para $enumDecode (necessário para fromJson)
T _enumDecode<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }
  return enumValues.entries.firstWhere((e) => e.value == source).key;
}

///
/// Model that represents the data of a x509Certificate
///
class X509CertificateData {
  /// The tbsCertificate data
  TbsCertificate? tbsCertificate;

  /// The version of the certificate
  @Deprecated('Use tbsCertificate.version instead')
  int version;

  /// The serialNumber of the certificate
  @Deprecated('Use tbsCertificate.serialNumber instead')
  BigInt serialNumber;

  /// The signatureAlgorithm of the certificate
  String signatureAlgorithm;

  /// The readable name of the signatureAlgorithm of the certificate
  String? signatureAlgorithmReadableName;

  /// The issuer data of the certificate
  @Deprecated('Use tbsCertificate.issuer instead')
  Map<String, String?> issuer;

  /// The validity of the certificate
  @Deprecated('Use tbsCertificate.validity instead')
  X509CertificateValidity validity;

  /// The subject data of the certificate
  @Deprecated('Use tbsCertificate.subject instead')
  Map<String, String?> subject;

  /// The sha1 thumbprint for the certificate
  String? sha1Thumbprint;

  /// The sha256 thumbprint for the certificate
  String? sha256Thumbprint;

  /// The md5 thumbprint for the certificate
  String? md5Thumbprint;

  /// The public key data from the certificate
  @Deprecated('Use tbsCertificate.subjectPublicKeyInfo instead')
  X509CertificatePublicKeyData publicKeyData;

  /// The subject alternative names
  @Deprecated('Use extensions.subjectAlternativNames instead')
  List<String>? subjectAlternativNames;

  /// The plain certificate pem string, that was used to decode.
  String? plain;

  /// The extended key usage extension
  @Deprecated('Use extensions.extKeyUsage instead')
  List<ExtendedKeyUsage>? extKeyUsage;

  /// The certificate extensions
  @Deprecated('Use tbsCertificate.extensions instead')
  X509CertificateDataExtensions? extensions;

  /// The signature
  String? signature;

  /// The tbsCertificateSeq as base64 string
  String? tbsCertificateSeqAsString;

  X509CertificateData({
    required this.version,
    required this.serialNumber,
    required this.signatureAlgorithm,
    required this.issuer,
    required this.validity,
    required this.subject,
    required this.tbsCertificate,
    this.signatureAlgorithmReadableName,
    this.sha1Thumbprint,
    this.sha256Thumbprint,
    this.md5Thumbprint,
    required this.publicKeyData,
    required this.subjectAlternativNames,
    this.plain,
    this.extKeyUsage,
    this.extensions,
    this.tbsCertificateSeqAsString,
    required this.signature,
  });

  /*
   * Json to X509CertificateData object
   */
  factory X509CertificateData.fromJson(Map<String, dynamic> json) {
    return X509CertificateData(
      version: json['version'] as int,
      serialNumber: BigInt.parse(json['serialNumber'] as String),
      signatureAlgorithm: json['signatureAlgorithm'] as String,
      issuer: Map<String, String?>.from(json['issuer'] as Map),
      validity: X509CertificateValidity.fromJson(
          json['validity'] as Map<String, dynamic>),
      subject: Map<String, String?>.from(json['subject'] as Map),
      tbsCertificate: json['tbsCertificate'] == null
          ? null
          : TbsCertificate.fromJson(
              json['tbsCertificate'] as Map<String, dynamic>),
      signatureAlgorithmReadableName:
          json['signatureAlgorithmReadableName'] as String?,
      sha1Thumbprint: json['sha1Thumbprint'] as String?,
      sha256Thumbprint: json['sha256Thumbprint'] as String?,
      md5Thumbprint: json['md5Thumbprint'] as String?,
      publicKeyData: X509CertificatePublicKeyData.fromJson(
          json['publicKeyData'] as Map<String, dynamic>),
      subjectAlternativNames: (json['subjectAlternativNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      plain: json['plain'] as String?,
      extKeyUsage: (json['extKeyUsage'] as List<dynamic>?)
          ?.map((e) => _enumDecode(_extendedKeyUsageEnumMap, e))
          .toList(),
      extensions: json['extensions'] == null
          ? null
          : X509CertificateDataExtensions.fromJson(
              json['extensions'] as Map<String, dynamic>),
      tbsCertificateSeqAsString: json['tbsCertificateSeqAsString'] as String?,
      signature: json['signature'] as String?,
    );
  }

  /*
   * X509CertificateData object to json
   */
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('tbsCertificate', tbsCertificate?.toJson());
    val['version'] = version;
    val['serialNumber'] = serialNumber.toString();
    val['signatureAlgorithm'] = signatureAlgorithm;
    writeNotNull(
        'signatureAlgorithmReadableName', signatureAlgorithmReadableName);
    val['issuer'] = issuer;
    val['validity'] = validity.toJson();
    val['subject'] = subject;
    writeNotNull('sha1Thumbprint', sha1Thumbprint);
    writeNotNull('sha256Thumbprint', sha256Thumbprint);
    writeNotNull('md5Thumbprint', md5Thumbprint);
    val['publicKeyData'] = publicKeyData.toJson();
    writeNotNull('subjectAlternativNames', subjectAlternativNames);
    writeNotNull('plain', plain);
    writeNotNull('extKeyUsage',
        extKeyUsage?.map((e) => _extendedKeyUsageEnumMap[e]!).toList());
    writeNotNull('extensions', extensions?.toJson());
    val['signature'] = signature;
    writeNotNull('tbsCertificateSeqAsString', tbsCertificateSeqAsString);
    return val;
  }
}