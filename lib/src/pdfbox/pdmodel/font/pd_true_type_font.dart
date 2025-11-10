import '../../../fontbox/encoding/win_ansi_encoding.dart';
import '../../../fontbox/ttf/cmap_lookup.dart';
import '../../../fontbox/ttf/true_type_font.dart';
import '../../../fontbox/ttf/ttf_parser.dart';
import '../../../io/random_access_read_buffered_file.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_name.dart';
import 'encoding/glyph_list.dart';
import 'pd_font_descriptor.dart';
import 'pd_simple_font.dart';
import 'true_type_embedder.dart';
import 'true_type_font_descriptor_builder.dart';

/// PDTrueTypeFont with width table population and deterministic subsetting.
class PDTrueTypeFont extends PDSimpleFont {
  PDTrueTypeFont._(
    COSDictionary dictionary,
    this._trueTypeFont,
    this._unicodeCMap,
    this._embedder,
    this._basePostScriptName,
  ) : super(
          dictionary,
          encoding: WinAnsiEncoding.instance,
          glyphList: GlyphList.getAdobeGlyphList(),
        ) {
    _initialiseWidths(_defaultFirstChar, _defaultLastChar);
  }

  static const int _defaultFirstChar = 32;
  static const int _defaultLastChar = 255;

  final TrueTypeFont _trueTypeFont;
  final CMapLookup? _unicodeCMap;
  final TrueTypeEmbedder _embedder;
  final String _basePostScriptName;
  late final PDFontDescriptor _fontDescriptor;

  late final double? _unitsPerEmScale;
  late final double _defaultWidth;
  late final List<double> _widths;
  late final int _firstChar;
  late final int _lastChar;

  /// Exposes the wrapped TrueType font for advanced use cases.
  TrueTypeFont get trueTypeFont => _trueTypeFont;

  /// Embedder used to create deterministic TrueType subsets.
  TrueTypeEmbedder get embedder => _embedder;

  /// Font descriptor associated with this TrueType font.
  PDFontDescriptor get fontDescriptor => _fontDescriptor;

  /// First character code covered by the widths array.
  int get firstChar => _firstChar;

  /// Last character code covered by the widths array.
  int get lastChar => _lastChar;

  /// Copy of the populated widths array in glyph space units.
  List<double> get widths => List<double>.unmodifiable(_widths);

  /// Width used when a glyph-specific value cannot be resolved.
  double get defaultGlyphWidth => _defaultWidth;

  /// PostScript name reported by the backing TrueType font.
  String get basePostScriptName => _basePostScriptName;

  /// Indicates whether a subset should be embedded instead of the full font.
  bool get needsSubset => _embedder.needsSubset;

  /// Loads a TrueType font from the provided [path].
  factory PDTrueTypeFont.fromFile(String path, {bool embedSubset = true}) {
    final parser = TtfParser();
    final randomAccess = RandomAccessReadBufferedFile(path);
    try {
      final font = parser.parse(randomAccess);
      return PDTrueTypeFont.fromFont(font, embedSubset: embedSubset);
    } finally {
      randomAccess.close();
    }
  }

  /// Wraps an existing [TrueTypeFont] instance.
  factory PDTrueTypeFont.fromFont(TrueTypeFont font, {bool embedSubset = true}) {
    final dictionary = COSDictionary()
      ..setName(COSName.type, 'Font')
      ..setName(COSName.subtype, COSName.trueType.name);

    final rawPostScriptName = font.getName();
    final postScriptName =
        (rawPostScriptName != null && rawPostScriptName.isNotEmpty)
            ? rawPostScriptName
            : 'TrueTypeFont';
    dictionary.setName(COSName.baseFont, postScriptName);
    dictionary.setName(COSName.encoding, 'WinAnsiEncoding');

    final unicodeCMap = font.getUnicodeCmapLookup(isStrict: false);
    final embedder = TrueTypeEmbedder(font, embedSubset: embedSubset);

    return PDTrueTypeFont._(
      dictionary,
      font,
      unicodeCMap,
      embedder,
      postScriptName,
    );
  }

  /// Adds the Unicode code points present in [text] to the pending subset.
  void addStringToSubset(String text) {
    if (text.isEmpty) {
      return;
    }
    for (final rune in text.runes) {
      _embedder.addToSubset(rune);
    }
  }

  /// Adds a Unicode [codePoint] to the pending subset.
  void addUnicodeCodePointToSubset(int codePoint) {
    _embedder.addToSubset(codePoint);
  }

  /// Adds a glyph code from the current encoding to the pending subset.
  void addEncodedCodeToSubset(int code) {
    final unicode = toUnicode(code);
    if (unicode == null || unicode.isEmpty) {
      return;
    }
    for (final rune in unicode.runes) {
      _embedder.addToSubset(rune);
    }
  }

  /// Adds multiple encoded character codes to the pending subset.
  void addEncodedCodesToSubset(Iterable<int> codes) {
    for (final code in codes) {
      addEncodedCodeToSubset(code);
    }
  }

  /// Ensures specific glyph ids remain in the subset when building the font.
  void addGlyphIdsToSubset(Iterable<int> glyphIds) {
    _embedder.addGlyphIds(glyphIds);
  }

  /// Produces a deterministic subset and optionally updates the base font name.
  TrueTypeSubsetResult buildSubset({bool updateBaseFontName = true}) {
    final result = _embedder.subset();
    final subsetFontName = '${result.tag}$_basePostScriptName';
    if (updateBaseFontName) {
      dictionary.setName(COSName.baseFont, subsetFontName);
      _fontDescriptor.fontName = subsetFontName;
    }
    _fontDescriptor.setFontFile2Data(result.fontData);
    return result;
  }

  @override
  double getWidthFromFont(int code) {
    if (code >= _firstChar && code <= _lastChar) {
      return _widths[code - _firstChar];
    }
    return _measureWidthInternal(code) ?? _defaultWidth;
  }

  /// Releases resources held by the underlying TrueType font.
  void close() {
    _trueTypeFont.close();
  }

  void _initialiseWidths(int firstChar, int lastChar) {
    _firstChar = firstChar;
    _lastChar = lastChar;
    _unitsPerEmScale = _computeUnitsPerEmScale();
    _defaultWidth = _widthForGlyphId(0) ?? 0;

    final span = lastChar - firstChar + 1;
    final widths = List<double>.filled(span, _defaultWidth, growable: false);
    final array = COSArray();

    for (var index = 0; index < span; index++) {
      final code = firstChar + index;
      final width = _measureWidthInternal(code) ?? _defaultWidth;
      widths[index] = width;
      array.add(COSFloat(width));
    }

    dictionary.setInt(COSName.firstChar, firstChar);
    dictionary.setInt(COSName.lastChar, lastChar);
    dictionary[COSName.widths] = array;
    _widths = widths;

    _fontDescriptor = _createFontDescriptor();
    dictionary[COSName.fontDescriptor] = _fontDescriptor.cosObject;
  }

  double? _computeUnitsPerEmScale() {
    final unitsPerEm = _trueTypeFont.unitsPerEm;
    if (unitsPerEm <= 0) {
      return null;
    }
    return 1000 / unitsPerEm;
  }

  double? _measureWidthInternal(int code) {
    final cmap = _unicodeCMap;
    if (cmap == null) {
      return null;
    }
    final unicode = toUnicode(code);
    if (unicode == null || unicode.isEmpty) {
      return null;
    }
    final iterator = unicode.runes.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    final gid = cmap.getGlyphId(iterator.current);
    if (gid <= 0) {
      return null;
    }
    return _widthForGlyphId(gid);
  }

  double? _widthForGlyphId(int gid) {
    final scale = _unitsPerEmScale;
    if (scale == null) {
      return null;
    }
    final advanceUnits = _trueTypeFont.getAdvanceWidth(gid);
    if (advanceUnits <= 0) {
      return null;
    }
    return advanceUnits * scale;
  }

  PDFontDescriptor _createFontDescriptor() {
    return TrueTypeFontDescriptorBuilder(
      font: _trueTypeFont,
      postScriptName: _basePostScriptName,
      missingWidth: _defaultWidth,
    ).build();
  }
}
