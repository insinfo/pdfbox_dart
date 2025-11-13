import 'dart:typed_data';

import '../../../../io/random_access_read.dart';
import '../../../pdfwriter/incremental_signing_context.dart';
import 'external_signing_support.dart';

/// Concrete implementation bridging COSWriter's incremental signing context
/// with the public external signing API.
class SigningSupport implements ExternalSigningSupport {
  SigningSupport(this._context);

  final IncrementalSigningContext _context;
  bool _contentRequested = false;

  @override
  RandomAccessRead getContent() {
    if (_contentRequested) {
      throw StateError('Content stream already requested');
    }
    _contentRequested = true;
    return _context.openContentToSign();
  }

  @override
  Future<void> setSignature(Uint8List signature) =>
      _context.applySignature(signature);
}