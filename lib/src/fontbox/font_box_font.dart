import 'cff/char_string_path.dart';
import 'util/bounding_box.dart';

/// Common contract for FontBox font implementations.
abstract class FontBoxFont {
  /// Returns the PostScript name of the font.
  String getName();

  /// Returns the font bounding box in PostScript units.
  BoundingBox getFontBBox();

  /// Returns the font matrix in PostScript units.
  List<num> getFontMatrix();

  /// Returns the outline associated with the glyph [name].
  CharStringPath getPath(String name);

  /// Returns the advance width of the glyph [name].
  double getWidth(String name);

  /// Returns `true` when the glyph [name] is present.
  bool hasGlyph(String name);
}
