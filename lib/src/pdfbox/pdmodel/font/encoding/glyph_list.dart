import '../../../../fontbox/util/glyph_list.dart' as fb;

/// PostScript glyph list wrapper mirroring the PDFBox encoding API.
class GlyphList {
  GlyphList._(this._delegate);

  final fb.GlyphList _delegate;

  static final GlyphList _adobeGlyphList =
      GlyphList._(fb.GlyphList.adobeGlyphList);

  static final GlyphList _zapfGlyphList =
      GlyphList._(fb.GlyphList.zapfDingbatsGlyphList);

  /// Returns the Adobe Glyph List (AGL).
  static GlyphList getAdobeGlyphList() => _adobeGlyphList;

  /// Returns the Zapf Dingbats glyph list.
  static GlyphList getZapfDingbats() => _zapfGlyphList;

  /// Returns the name associated with a single Unicode [codePoint].
  String codePointToName(int codePoint) =>
      _delegate.codePointToName(codePoint);

  /// Returns the name associated with a [unicodeSequence].
  String sequenceToName(String unicodeSequence) =>
      _delegate.sequenceToName(unicodeSequence);

    /// Returns the Unicode characters mapped from a PostScript [name].
    String? toUnicode(String? name) {
        if (name == null) {
            return null;
        }
        return _delegate.unicodeForName(name);
    }

  /// Returns `true` when the glyph [name] is present in the list.
  bool contains(String name) => _delegate.contains(name);
}
