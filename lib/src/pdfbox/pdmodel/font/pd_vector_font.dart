import '../../../fontbox/cff/char_string_path.dart';

/// Defines the operations provided by vector outline fonts.
abstract class PDVectorFont {
  /// Resolves the glyph outline associated with [code].
  CharStringPath getPath(int code);

  /// Resolves a normalized glyph outline associated with [code].
  CharStringPath getNormalizedPath(int code);

  /// Indicates whether the glyph mapped from [code] exists in the font.
  bool hasGlyph(int code);
}
