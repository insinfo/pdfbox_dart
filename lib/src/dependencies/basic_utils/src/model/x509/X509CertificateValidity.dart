



///
/// Model that represents the validity data of a x509Certificate
///

class X509CertificateValidity {
  /// The start date
  DateTime notBefore;

  /// The end date
  DateTime notAfter;

  X509CertificateValidity({required this.notBefore,required this.notAfter});

  /*
   * Json to X509CertificateValidity object
   */
  factory X509CertificateValidity.fromJson(Map<String, dynamic> json) =>
         throw  UnimplementedError();

  /*
   * X509CertificateValidity object to json
   */
  Map<String, dynamic> toJson() =>    throw  UnimplementedError();
}
