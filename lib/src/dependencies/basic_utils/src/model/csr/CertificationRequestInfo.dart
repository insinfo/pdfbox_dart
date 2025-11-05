import '../../../src/model/csr/CertificateSigningRequestExtensions.dart';
import '../../../src/model/csr/SubjectPublicKeyInfo.dart';




class CertificationRequestInfo {
  /// The version
  int? version;

  /// The subject data of the certificate singing request
  Map<String, String>? subject;

  /// The public key information
  SubjectPublicKeyInfo? publicKeyInfo;

  CertificateSigningRequestExtensions? extensions;

  CertificationRequestInfo({
    this.subject,
    this.version,
    this.publicKeyInfo,
    this.extensions,
  });

  /*
   * Json to CertificationRequestInfo object
   */
  factory CertificationRequestInfo.fromJson(Map<String, dynamic> json) =>
      throw  UnimplementedError();

  /*
   * CertificationRequestInfo object to json
   */
  Map<String, dynamic> toJson() =>  throw  UnimplementedError();
}
