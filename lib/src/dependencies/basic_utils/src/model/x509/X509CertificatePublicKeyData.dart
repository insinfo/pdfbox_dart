import 'dart:typed_data';
import '../../../src/model/csr/SubjectPublicKeyInfo.dart';

///
/// Model that a public key from a X509Certificate
///
class X509CertificatePublicKeyData {
  /// The algorithm of the public key
  String? algorithm;

  /// The readable name of the algorithm
  String? algorithmReadableName;

  /// The parameter of the public key
  String? parameter;

  /// The readable name of the parameter
  String? parameterReadableName;

  /// The key length of the public key
  int? length;

  /// The sha1 thumbprint of the public key
  String? sha1Thumbprint;

  /// The sha256 thumbprint of the public key
  String? sha256Thumbprint;

  /// The bytes representing the public key as String
  String? bytes;

  Uint8List? plainSha1;

  /// The exponent used on a RSA public key
  int? exponent;

  X509CertificatePublicKeyData({
    this.algorithm,
    this.length,
    this.sha1Thumbprint,
    this.sha256Thumbprint,
    this.bytes,
    this.plainSha1,
    this.algorithmReadableName,
    this.parameter,
    this.parameterReadableName,
    this.exponent,
  });

  /*
   * Json to X509CertificatePublicKeyData object
   */
  factory X509CertificatePublicKeyData.fromJson(Map<String, dynamic> json) {
    return X509CertificatePublicKeyData(
      algorithm: json['algorithm'] as String?,
      length: json['length'] as int?,
      sha1Thumbprint: json['sha1Thumbprint'] as String?,
      sha256Thumbprint: json['sha256Thumbprint'] as String?,
      bytes: json['bytes'] as String?,
      plainSha1: X509CertificatePublicKeyData.plainSha1FromJson(
          json['plainSha1'] as List<int>?),
      algorithmReadableName: json['algorithmReadableName'] as String?,
      parameter: json['parameter'] as String?,
      parameterReadableName: json['parameterReadableName'] as String?,
      exponent: json['exponent'] as int?,
    );
  }

  /*
   * X509CertificatePublicKeyData object to json
   */
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('algorithm', algorithm);
    writeNotNull('algorithmReadableName', algorithmReadableName);
    writeNotNull('parameter', parameter);
    writeNotNull('parameterReadableName', parameterReadableName);
    writeNotNull('length', length);
    writeNotNull('sha1Thumbprint', sha1Thumbprint);
    writeNotNull('sha256Thumbprint', sha256Thumbprint);
    writeNotNull('bytes', bytes);
    writeNotNull(
        'plainSha1', X509CertificatePublicKeyData.plainSha1ToJson(plainSha1));
    writeNotNull('exponent', exponent);
    return val;
  }

  static Uint8List? plainSha1FromJson(List<int>? json) {
    if (json == null) {
      return null;
    }
    return Uint8List.fromList(json);
  }

  static List<int>? plainSha1ToJson(Uint8List? object) {
    if (object == null) {
      return null;
    }
    return object.toList();
  }

  X509CertificatePublicKeyData.fromSubjectPublicKeyInfo(
      SubjectPublicKeyInfo info) {
    algorithm = info.algorithm;
    length = info.length;
    sha1Thumbprint = info.sha1Thumbprint;
    sha256Thumbprint = info.sha256Thumbprint;
    bytes = info.bytes;
    algorithmReadableName = info.algorithmReadableName;
    parameter = info.parameter;
    parameterReadableName = info.parameterReadableName;
    exponent = info.exponent;
  }
}