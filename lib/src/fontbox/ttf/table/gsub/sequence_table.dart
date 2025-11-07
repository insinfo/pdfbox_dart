import 'dart:collection';

/// Holds the glyph sequence produced by a lookup type 2 substitution.
class SequenceTable {
  SequenceTable(int glyphCount, List<int> substituteGlyphIds)
      : glyphCount = glyphCount,
        substituteGlyphIds = UnmodifiableListView<int>(substituteGlyphIds);

  final int glyphCount;
  final List<int> substituteGlyphIds;

  @override
  String toString() =>
      'SequenceTable{glyphCount=$glyphCount, substituteGlyphIDs=$substituteGlyphIds}';
}
