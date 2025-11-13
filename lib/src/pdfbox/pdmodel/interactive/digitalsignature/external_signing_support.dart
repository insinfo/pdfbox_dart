import 'dart:typed_data';

import '../../../../io/random_access_read.dart';

/// Interface for workflows where the CMS signature is produced outside the
/// library. Mirrors PDFBox's ExternalSigningSupport contract.
abstract class ExternalSigningSupport {
  /// Returns the exact bytes that must be signed. Callers are responsible for
  /// closing the returned reader when finished.
  RandomAccessRead getContent();

  /// Injects the externally created CMS signature into the prepared
  /// incremental update and writes the final document to the configured sink.
  Future<void> setSignature(Uint8List signature);
}