import 'dart:collection';

/// Describes a ligature definition inside lookup type 4 substitutions.
class LigatureTable {
  LigatureTable(int ligatureGlyph, int componentCount, List<int> componentGlyphIds)
      : ligatureGlyph = ligatureGlyph,
        componentCount = componentCount,
        componentGlyphIds = UnmodifiableListView<int>(componentGlyphIds);

  final int ligatureGlyph;
  final int componentCount;
  final List<int> componentGlyphIds;

  @override
  String toString() =>
      'LigatureTable[ligatureGlyph=$ligatureGlyph, componentCount=$componentCount]';
}
