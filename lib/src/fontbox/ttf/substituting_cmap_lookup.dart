import 'cmap_lookup.dart';
import 'cmap_subtable.dart';
import 'glyph_substitution_table.dart';
import 'open_type_script.dart';
import 'jstf/jstf_lookup_control.dart';

/// CMap lookup that performs glyph substitutions using the GSUB table.
class SubstitutingCmapLookup implements CMapLookup {
  SubstitutingCmapLookup(
    this._cmap,
    this._gsubTable,
    List<String>? enabledFeatures,
    {JstfLookupControl? jstfControl}
  )   : _enabledFeatures = enabledFeatures ?? const <String>[],
        _jstfControl = jstfControl;

  final CmapSubtable _cmap;
  final GlyphSubstitutionTable _gsubTable;
  final List<String> _enabledFeatures;
  JstfLookupControl? _jstfControl;

  JstfLookupControl? get jstfControl => _jstfControl;

  set jstfControl(JstfLookupControl? value) => _jstfControl = value;

  @override
  int getGlyphId(int codePoint, [int? variationSelector]) {
    final baseGlyphId = _cmap.getGlyphId(codePoint, variationSelector);
    if (baseGlyphId == 0) {
      return 0;
    }
    final scriptTags = OpenTypeScript.getScriptTags(codePoint);
    return _gsubTable.getSubstitution(
      baseGlyphId,
      scriptTags,
      _enabledFeatures,
      jstfControl: _jstfControl,
    );
  }

  @override
  List<int>? getCharCodes(int glyphId) {
    final unsubstituted = _gsubTable.getUnsubstitution(glyphId);
    return _cmap.getCharCodes(unsubstituted);
  }

  /// Mapeia uma lista de codepoints aplicando seletores de variação e GSUB.
  List<int> mapCodePoints(Iterable<int> codePoints) {
    final source = codePoints is List<int>
        ? codePoints
        : List<int>.from(codePoints, growable: false);
    final glyphIds = <int>[];

    for (var index = 0; index < source.length; index++) {
      final codePoint = source[index];
      if (CmapSubtable.isVariationSelector(codePoint)) {
        continue;
      }

      int? variationSelector;
      if (index + 1 < source.length &&
          CmapSubtable.isVariationSelector(source[index + 1])) {
        variationSelector = source[index + 1];
        index++;
      }

      glyphIds.add(getGlyphId(codePoint, variationSelector));
    }

    return glyphIds;
  }
}
