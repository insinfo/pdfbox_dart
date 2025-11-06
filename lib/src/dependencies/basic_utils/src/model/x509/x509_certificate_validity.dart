///
/// Model that represents the validity data of a x509Certificate
///
class X509CertificateValidity {
  /// The start date
  DateTime notBefore;

  /// The end date
  DateTime notAfter;

  X509CertificateValidity({required this.notBefore, required this.notAfter});

  /*
   * Json to X509CertificateValidity object
   */
  factory X509CertificateValidity.fromJson(Map<String, dynamic> json) {
    return X509CertificateValidity(
      notBefore: DateTime.parse(json['notBefore'] as String),
      notAfter: DateTime.parse(json['notAfter'] as String),
    );
  }

  /*
   * X509CertificateValidity object to json
   */
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'notBefore': notBefore.toIso8601String(),
      'notAfter': notAfter.toIso8601String(),
    };
  }
}