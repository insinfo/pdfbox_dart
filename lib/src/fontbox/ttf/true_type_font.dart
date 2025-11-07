import 'cmap_table.dart';
import 'glyph_substitution_table.dart';
import 'ttf_table.dart';

/// Minimal TrueType font container tracking registered tables and glyph count.
class TrueTypeFont implements HasGlyphCount {
  TrueTypeFont({int glyphCount = 0}) : numberOfGlyphs = glyphCount;

  final Map<String, TtfTable> _tables = <String, TtfTable>{};

  @override
  int numberOfGlyphs;

  bool enableGsub = true;
  final List<String> enabledGsubFeatures = <String>[];

  void addTable(TtfTable table) {
    final tag = table.tag;
    if (tag == null) {
      throw ArgumentError('Table tag must be set before registration');
    }
    _tables[tag] = table;
  }

  TtfTable? getTable(String tag) => _tables[tag];

  Iterable<TtfTable> get tables => _tables.values;

  CmapTable? getCmapTable() => getTable(CmapTable.tableTag) as CmapTable?;

  GlyphSubstitutionTable? getGsubTable() =>
      getTable(GlyphSubstitutionTable.tableTag) as GlyphSubstitutionTable?;
}
