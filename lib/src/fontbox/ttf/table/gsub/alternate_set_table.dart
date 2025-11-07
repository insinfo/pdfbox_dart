import 'dart:collection';

/// Represents the alternate glyph set used by lookup type 3 substitutions.
class AlternateSetTable {
  AlternateSetTable(int glyphCount, List<int> alternateGlyphIds)
      : glyphCount = glyphCount,
        alternateGlyphIds = UnmodifiableListView<int>(alternateGlyphIds);

  final int glyphCount;
  final List<int> alternateGlyphIds;

  @override
  String toString() =>
      'AlternateSetTable{glyphCount=$glyphCount, alternateGlyphIDs=$alternateGlyphIds}';
}
