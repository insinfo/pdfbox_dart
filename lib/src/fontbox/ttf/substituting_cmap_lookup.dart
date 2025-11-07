import 'cmap_lookup.dart';
import 'cmap_subtable.dart';
import 'glyph_substitution_table.dart';
import 'open_type_script.dart';

/// CMap lookup that performs glyph substitutions using the GSUB table.
class SubstitutingCmapLookup implements CMapLookup {
  SubstitutingCmapLookup(
    this._cmap,
    this._gsubTable,
    List<String>? enabledFeatures,
  ) : _enabledFeatures = enabledFeatures ?? const <String>[];

  final CmapSubtable _cmap;
  final GlyphSubstitutionTable _gsubTable;
  final List<String> _enabledFeatures;

  @override
  int getGlyphId(int codePoint) {
    final baseGlyphId = _cmap.getGlyphId(codePoint);
    if (baseGlyphId == 0) {
      return 0;
    }
    final scriptTags = OpenTypeScript.getScriptTags(codePoint);
    return _gsubTable.getSubstitution(baseGlyphId, scriptTags, _enabledFeatures);
  }

  @override
  List<int>? getCharCodes(int glyphId) {
    final unsubstituted = _gsubTable.getUnsubstitution(glyphId);
    return _cmap.getCharCodes(unsubstituted);
  }
}
