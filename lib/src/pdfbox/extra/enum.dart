/// Specifies the available permissions on certificated document.
enum PdfCertificationFlags {
  /// Restrict any changes to the document.
  forbidChanges,

  /// Only allow form fill-in actions on this document.
  allowFormFill,

  /// Only allow commenting and form fill-in actions on this document.
  allowComments,
}

/// Specifies the cryptographic standard.
enum CryptographicStandard {
  /// Cryptographic Message Syntax.
  cms,

  /// CMS Advanced Electronic Signatures.
  cades,
}

/// Specifies the digestion algorithm.
enum DigestAlgorithm {
  /// SHA1 message digest algorithm.
  sha1,

  /// SHA256 message digest algorithm.
  sha256,

  /// SHA384 message digest algorithm.
  sha384,

  /// SHA512 message digest algorithm.
  sha512,
}

