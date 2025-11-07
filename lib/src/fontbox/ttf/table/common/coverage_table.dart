/// Base contract for coverage tables used in OpenType layout lookups.
abstract class CoverageTable {
  const CoverageTable(this.coverageFormat);

  final int coverageFormat;

  int getCoverageIndex(int glyphId);

  int getGlyphId(int index);

  int getSize();
}
