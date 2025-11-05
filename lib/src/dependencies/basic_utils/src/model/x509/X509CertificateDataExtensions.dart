import '../../../src/model/x509/ExtendedKeyUsage.dart';
import '../../../src/model/x509/KeyUsage.dart';
import '../../../src/model/x509/VmcData.dart';




///
/// Model that represents the extensions of a x509Certificate
///

class X509CertificateDataExtensions {
  /// The subject alternative names
  List<String>? subjectAlternativNames;

  /// The extended key usage extension
  List<ExtendedKeyUsage>? extKeyUsage;

  /// The key usage extension
  List<KeyUsage>? keyUsage;

  /// The cA field of the basic constraints extension
  bool? cA;

  /// The pathLenConstraint field of the basic constraints extension
  int? pathLenConstraint;

  /// The base64 encoded VMC logo
  VmcData? vmc;

  /// The distribution points for the crl files. Normally a url.
  List<String>? cRLDistributionPoints;

  X509CertificateDataExtensions({
    this.subjectAlternativNames,
    this.extKeyUsage,
    this.keyUsage,
    this.cA,
    this.pathLenConstraint,
    this.vmc,
    this.cRLDistributionPoints,
  });

  /*
   * Json to X509CertificateDataExtensions object
   */
  factory X509CertificateDataExtensions.fromJson(Map<String, dynamic> json) =>
        throw  UnimplementedError();

  /*
   * X509CertificateDataExtensions object to json
   */
  Map<String, dynamic> toJson() =>    throw  UnimplementedError();
}
