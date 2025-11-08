import 'encoding/encoding.dart';

/// Contract for fonts that expose a PostScript encoding vector.
abstract class EncodedFont {
  /// Returns the encoding vector associated with this font.
  Encoding? getEncoding();
}
