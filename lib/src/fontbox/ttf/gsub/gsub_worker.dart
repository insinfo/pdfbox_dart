/// Applies language-specific GSUB transformations to glyph IDs.
abstract class GsubWorker {
  /// Applies GSUB and language-specific transformations.
  List<int> applyTransforms(List<int> originalGlyphIds);
}
