import 'dart:typed_data';

/// Callback interface for signing PDF byte ranges.
abstract class SignatureInterface {
  /// Signs the provided content and returns the raw signature bytes.
  Uint8List sign(Uint8List content);
}
