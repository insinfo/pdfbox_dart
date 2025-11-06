import 'extended_key_usage.dart';
import 'key_usage.dart';
import 'vmc_data.dart';

// Mapas de Enum para String (baseados no código gerado)
const _extendedKeyUsageEnumMap = {
  ExtendedKeyUsage.SERVER_AUTH: 'SERVER_AUTH',
  ExtendedKeyUsage.CLIENT_AUTH: 'CLIENT_AUTH',
  ExtendedKeyUsage.CODE_SIGNING: 'CODE_SIGNING',
  ExtendedKeyUsage.EMAIL_PROTECTION: 'EMAIL_PROTECTION',
  ExtendedKeyUsage.TIME_STAMPING: 'TIME_STAMPING',
  ExtendedKeyUsage.OCSP_SIGNING: 'OCSP_SIGNING',
  ExtendedKeyUsage.BIMI: 'BIMI',
};

const _keyUsageEnumMap = {
  KeyUsage.DIGITAL_SIGNATURE: 'DIGITAL_SIGNATURE',
  KeyUsage.NON_REPUDIATION: 'NON_REPUDIATION',
  KeyUsage.KEY_ENCIPHERMENT: 'KEY_ENCIPHERMENT',
  KeyUsage.DATA_ENCIPHERMENT: 'DATA_ENCIPHERMENT',
  KeyUsage.KEY_AGREEMENT: 'KEY_AGREEMENT',
  KeyUsage.KEY_CERT_SIGN: 'KEY_CERT_SIGN',
  KeyUsage.CRL_SIGN: 'CRL_SIGN',
  KeyUsage.ENCIPHER_ONLY: 'ENCIPHER_ONLY',
  KeyUsage.DECIPHER_ONLY: 'DECIPHER_ONLY',
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
/// Model that represents the extensions of a x509Certificate
///
class X509CertificateDataExtensions {
  /// The subject alternative names
  List<String>? subjectAlternativNames;

  /// The extended key usage extension
  List<ExtendedKeyUsage>? extKeyUsage;

  /// The key usage extension
  List<KeyUsage>? keyUsage;

  /// The cA field of the basic constraints extension
  bool? cA;

  /// The pathLenConstraint field of the basic constraints extension
  int? pathLenConstraint;

  /// The base64 encoded VMC logo
  VmcData? vmc;

  /// The distribution points for the crl files. Normally a url.
  List<String>? cRLDistributionPoints;

  X509CertificateDataExtensions({
    this.subjectAlternativNames,
    this.extKeyUsage,
    this.keyUsage,
    this.cA,
    this.pathLenConstraint,
    this.vmc,
    this.cRLDistributionPoints,
  });

  /*
   * Json to X509CertificateDataExtensions object
   */
  factory X509CertificateDataExtensions.fromJson(Map<String, dynamic> json) {
    return X509CertificateDataExtensions(
      subjectAlternativNames: (json['subjectAlternativNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      extKeyUsage: (json['extKeyUsage'] as List<dynamic>?)
          ?.map((e) => _enumDecode(_extendedKeyUsageEnumMap, e))
          .toList(),
      keyUsage: (json['keyUsage'] as List<dynamic>?)
          ?.map((e) => _enumDecode(_keyUsageEnumMap, e))
          .toList(),
      cA: json['cA'] as bool?,
      pathLenConstraint: json['pathLenConstraint'] as int?,
      vmc: json['vmc'] == null
          ? null
          : VmcData.fromJson(json['vmc'] as Map<String, dynamic>),
      cRLDistributionPoints: (json['cRLDistributionPoints'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  /*
   * X509CertificateDataExtensions object to json
   */
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('subjectAlternativNames', subjectAlternativNames);
    writeNotNull('extKeyUsage',
        extKeyUsage?.map((e) => _extendedKeyUsageEnumMap[e]!).toList());
    writeNotNull(
        'keyUsage', keyUsage?.map((e) => _keyUsageEnumMap[e]!).toList());
    writeNotNull('cA', cA);
    writeNotNull('pathLenConstraint', pathLenConstraint);
    writeNotNull('vmc', vmc?.toJson());
    writeNotNull('cRLDistributionPoints', cRLDistributionPoints);
    return val;
  }
}