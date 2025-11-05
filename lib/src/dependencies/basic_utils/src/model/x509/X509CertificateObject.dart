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
  factory X509CertificateObject.fromJson(Map<String, dynamic> json) {
    return X509CertificateObject(
      json['data'] == null
          ? null
          : X509CertificateData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  /*
   * X509CertificateObject object to json
   */
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('data', data?.toJson());
    return val;
  }
}