import 'dart:typed_data';

import '../../../crypto/basic_utils/core/crypto_utils.dart';
import '../../../crypto/pkcs/core/common.dart';
import '../../../crypto/pkcs/core/pkcs7_builder.dart';
import '../../../crypto/x509/core/x509_certificates.dart';

/// Helper to generate CMS/PKCS#7 detached signatures.
class PdfCmsSigner {
  const PdfCmsSigner._();

  /// Signs the [contentDigest] with the provided private key and certificate.
  ///
  /// This creates a detached CMS signature (PKCS#7) using SHA-256 and RSA.
  static Uint8List signDetachedSha256RsaFromPem({
    required Uint8List contentDigest,
    required String privateKeyPem,
    String? privateKeyPassword,
    required String certificatePem,
    List<String> chainPem = const <String>[],
  }) {
    // 1. Parse Keys and Certs
    final privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
    final certificate = X509Certificate.fromPem(certificatePem);
    final chain = chainPem.map((pem) => X509Certificate.fromPem(pem)).toList();

    // 2. Build PKCS7
    final builder = Pkcs7Builder();

    // Add certificates
    builder.addCertificate(certificate);
    for (final cert in chain) {
      builder.addCertificate(cert);
    }

    // 3. Create Signer Info
    // Note: Pkcs7SignerInfoBuilder needs to be configured with the digest to sign.
    // However, Pkcs7SignerInfoBuilder.rsa(...) usually takes the raw data and HASHES it inside?
    // Or does it take the digest?
    // Let's check Pkcs7SignerInfoBuilder implementation.

    // If the builder hash logic is internal, we might need to be careful.
    // IF the builder EXPECTS the pre-computed digest, we use that.

    final signerInfo = Pkcs7SignerInfoBuilder.rsa(
      issuer: certificate,
      privateKey: privateKey,
      digestAlgorithm: HashAlgorithm.sha256,
    );

    // addSMimeDigest adds the authenticated attributes including message-digest.
    signerInfo.addSMimeDigest(digest: contentDigest);

    builder.addSignerInfo(signerInfo);

    // 4. Build and return DER
    final pkcs7 = builder.build();
    return pkcs7.der;
  }

  /// Signs the [contentDigest] with the provided EC private key and certificate.
  ///
  /// This creates a detached CMS signature (PKCS#7) using SHA-256 and ECDSA.
  static Uint8List signDetachedSha256EcdsaFromPem({
    required Uint8List contentDigest,
    required String privateKeyPem,
    required String certificatePem,
    List<String> chainPem = const <String>[],
  }) {
    // 1. Parse Keys and Certs
    final privateKey = CryptoUtils.ecPrivateKeyFromPem(privateKeyPem);
    final certificate = X509Certificate.fromPem(certificatePem);
    final chain = chainPem.map((pem) => X509Certificate.fromPem(pem)).toList();

    // 2. Build PKCS7
    final builder = Pkcs7Builder();

    // Add certificates
    builder.addCertificate(certificate);
    for (final cert in chain) {
      builder.addCertificate(cert);
    }

    // 3. Create Signer Info
    final signerInfo = Pkcs7SignerInfoBuilder.ecdsa(
      issuer: certificate,
      privateKey: privateKey,
      digestAlgorithm: HashAlgorithm.sha256,
    );

    // addSMimeDigest adds the authenticated attributes including message-digest.
    signerInfo.addSMimeDigest(digest: contentDigest);

    builder.addSignerInfo(signerInfo);

    // 4. Build and return DER
    final pkcs7 = builder.build();
    return pkcs7.der;
  }
}
