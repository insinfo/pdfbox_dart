/// Describes the contour and coordinate data associated with a glyph.
///
/// This mirrors the interface exposed by the PDFBox Java implementation and
/// is consumed by both simple and composite glyph descriptions.
abstract class GlyphDescription {
  /// Returns the point index marking the end of the contour at [contourIndex].
  int getEndPtOfContours(int contourIndex);

  /// Returns the raw flag byte for the point at [pointIndex].
  int getFlags(int pointIndex);

  /// Returns the absolute X coordinate for the point at [pointIndex].
  int getXCoordinate(int pointIndex);

  /// Returns the absolute Y coordinate for the point at [pointIndex].
  int getYCoordinate(int pointIndex);

  /// Whether this description represents a composite glyph.
  bool get isComposite;

  /// Total number of points described.
  int get pointCount;

  /// Total number of contours described.
  int get contourCount;

  /// Resolves composite references. No-op for simple glyphs.
  void resolve();
}
