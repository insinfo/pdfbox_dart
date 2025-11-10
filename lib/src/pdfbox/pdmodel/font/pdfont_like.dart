import '../../../fontbox/util/bounding_box.dart';
import '../../util/matrix.dart';
import '../../util/vector.dart';
import 'pd_font_descriptor.dart';

/// Common contract for font-like objects exposed by PDModel.
abstract class PDFontLike {
  /// PostScript base name or Type 3 name.
  String? getName();

  /// Returns the associated font descriptor when present.
  PDFontDescriptor? getFontDescriptor();

  /// Returns the transformation from glyph to text space.
  Matrix getFontMatrix();

  /// Returns the font bounding box in glyph space.
  BoundingBox getBoundingBox();

  /// Returns the position vector for the supplied character code.
  Vector getPositionVector(int code);

  /// Returns the advance height for [code] in glyph space.
  double getHeight(int code);

  /// Returns the advance width for [code] in glyph space.
  double getWidth(int code);

  /// Indicates whether the font dictionary provides an explicit width for [code].
  bool hasExplicitWidth(int code);

  /// Returns the width from the embedded font program when available.
  double getWidthFromFont(int code);

  /// Indicates whether the font program is embedded.
  bool isEmbedded();

  /// Indicates whether the font program is damaged.
  bool isDamaged();

  /// Returns the average width of glyphs in text space units.
  double getAverageFontWidth();
}
