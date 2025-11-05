import '../../../src/model/x509/X509CertificateData.dart';




///
/// Model that represents a x509Certificate
///

class X509CertificateObject {
  X509CertificateData? data;

  X509CertificateObject(this.data);

  /*
   * Json to X509CertificateObject object
   */
  factory X509CertificateObject.fromJson(Map<String, dynamic> json) =>
          throw  UnimplementedError();

  /*
   * X509CertificateObject object to json
   */
  Map<String, dynamic> toJson() =>     throw  UnimplementedError();
}
