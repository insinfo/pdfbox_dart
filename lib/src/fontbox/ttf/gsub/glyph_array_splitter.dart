/// Splits a sequence of glyph IDs into chunks that may be substituted.
abstract class GlyphArraySplitter {
  /// Returns a list of glyph chunks ready for GSUB processing.
  List<List<int>> split(List<int> glyphIds);
}
