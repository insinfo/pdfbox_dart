

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
   */ // TODO falta implementar
  factory CertificateSigningRequestExtensions.fromJson(
          Map<String, dynamic> json) =>
    throw  UnimplementedError();

  /*
   * CertificateSigningRequestExtensions object to json
   */ // TODO falta implementar
  Map<String, dynamic> toJson() =>
      throw  UnimplementedError();
}
