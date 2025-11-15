/// Base class for data required to decrypt a PDF document.
///
/// Mirrors the marker type used by Apache PDFBox and allows the
/// security handlers to accept either password or certificate based
/// credentials without coupling to a concrete implementation.
abstract class DecryptionMaterial {
  const DecryptionMaterial();
}
