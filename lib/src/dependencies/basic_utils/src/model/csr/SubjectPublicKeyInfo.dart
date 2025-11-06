///
/// Model that a public key from a X509Certificate
///
class SubjectPublicKeyInfo {
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

  /// The exponent used on a RSA public key
  int? exponent;

  SubjectPublicKeyInfo({
    this.algorithm,
    this.length,
    this.sha1Thumbprint,
    this.sha256Thumbprint,
    this.bytes,
    this.algorithmReadableName,
    this.parameter,
    this.parameterReadableName,
    this.exponent,
  });

  /*
   * Json to SubjectPublicKeyInfo object
   */
  factory SubjectPublicKeyInfo.fromJson(Map<String, dynamic> json) {
    return SubjectPublicKeyInfo(
      algorithm: json['algorithm'] as String?,
      length: json['length'] as int?,
      sha1Thumbprint: json['sha1Thumbprint'] as String?,
      sha256Thumbprint: json['sha256Thumbprint'] as String?,
      bytes: json['bytes'] as String?,
      algorithmReadableName: json['algorithmReadableName'] as String?,
      parameter: json['parameter'] as String?,
      parameterReadableName: json['parameterReadableName'] as String?,
      exponent: json['exponent'] as int?,
    );
  }

  /*
   * SubjectPublicKeyInfo object to json
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
    writeNotNull('exponent', exponent);
    return val;
  }
}