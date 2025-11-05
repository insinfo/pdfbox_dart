import '../../../src/model/x509/X509CertificateData.dart';





class Pkcs7CertificateData {
  /// The syntax version number
  int? version;

  /// Indicates the type of the associated content.
  String? contentType;

  /// The certificates within the PKCS7
  List<X509CertificateData>? certificates;

  Pkcs7CertificateData({this.version, this.certificates, this.contentType});

  /*
   * Json to Pkcs7CertificateData object
   */
  factory Pkcs7CertificateData.fromJson(Map<String, dynamic> json) =>
     throw  UnimplementedError();

  /*
   * Pkcs7CertificateData object to json
   */
  Map<String, dynamic> toJson() =>  throw  UnimplementedError();
}
