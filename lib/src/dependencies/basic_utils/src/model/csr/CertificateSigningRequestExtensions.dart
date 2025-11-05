///
/// Model that represents the extensions of a x509Certificate
///
class CertificateSigningRequestExtensions {
  /// The subject alternative names
  List<String>? subjectAlternativNames;

  // basicConstraints
  // authorityKeyIdentifier
  // cRLDistributionPoints
  // keyUsage
  // extKeyUsage
  // certificatePolicies
  // authorityInfoAccess => OCSP und caIssuers

  CertificateSigningRequestExtensions({
    this.subjectAlternativNames,
  });

  /*
   * Json to CertificateSigningRequestExtensions object
   */
  factory CertificateSigningRequestExtensions.fromJson(
      Map<String, dynamic> json) {
    return CertificateSigningRequestExtensions(
      subjectAlternativNames:
          (json['subjectAlternativNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
    );
  }

  /*
   * CertificateSigningRequestExtensions object to json
   */
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('subjectAlternativNames', subjectAlternativNames);
    return val;
  }
}