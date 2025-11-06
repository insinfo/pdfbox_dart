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
  factory Pkcs7CertificateData.fromJson(Map<String, dynamic> json) {
    return Pkcs7CertificateData(
      version: json['version'] as int?,
      certificates: (json['certificates'] as List<dynamic>?)
          ?.map((e) => X509CertificateData.fromJson(e as Map<String, dynamic>))
          .toList(),
      contentType: json['contentType'] as String?,
    );
  }

  /*
   * Pkcs7CertificateData object to json
   */
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('version', version);
    writeNotNull('contentType', contentType);
    writeNotNull(
        'certificates', certificates?.map((e) => e.toJson()).toList());
    return val;
  }
}