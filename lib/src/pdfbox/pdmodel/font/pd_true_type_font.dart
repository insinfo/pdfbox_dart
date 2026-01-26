import '../../../fontbox/encoding/encoding.dart';
import '../../../fontbox/encoding/win_ansi_encoding.dart';
import '../../../fontbox/cff/char_string_path.dart';
import '../../../fontbox/ttf/cmap_lookup.dart';
import '../../../fontbox/ttf/glyph_renderer.dart' as ttf_glyph;
import '../../../fontbox/ttf/true_type_font.dart';
import '../../../fontbox/ttf/ttf_parser.dart';
import '../../../io/random_access_read_buffered_file.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_name.dart';
import 'encoding/dictionary_encoding.dart';
import 'encoding/glyph_list.dart';
import 'pd_font_descriptor.dart';
import 'pd_simple_font.dart';
import 'pd_vector_font.dart';
import 'font_mappers.dart';
import 'true_type_font_box_adapter.dart';
import 'true_type_embedder.dart';
import 'true_type_font_descriptor_builder.dart';

/// PDTrueTypeFont with width table population and deterministic subsetting.
class PDTrueTypeFont extends PDSimpleFont implements PDVectorFont {
  PDTrueTypeFont._(
    COSDictionary dictionary,
    this._trueTypeFont,
    this._unicodeCMap,
    this._embedder,
    this._basePostScriptName, {
    required Encoding encoding,
  }) : super(
          dictionary,
          encoding: encoding,
          glyphList: GlyphList.getAdobeGlyphList(),
        ) {
    if (dictionary.containsKey(COSName.widths)) {
      _readWidths();
    } else {
      _initialiseWidths(_defaultFirstChar, _defaultLastChar);
    }
  }

  static const int _defaultFirstChar = 32;
  static const int _defaultLastChar = 255;

  final TrueTypeFont _trueTypeFont;
  final CMapLookup? _unicodeCMap;
  final TrueTypeEmbedder _embedder;
  final String _basePostScriptName;
  late final PDFontDescriptor _fontDescriptor;

  late final TrueTypeFontBoxAdapter _fontBoxAdapter =
      TrueTypeFontBoxAdapter(_trueTypeFont);

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
  factory PDTrueTypeFont.fromFont(TrueTypeFont font,
      {bool embedSubset = true}) {
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
      encoding: WinAnsiEncoding.instance,
    );
  }

  /// Creates a [PDTrueTypeFont] from a [COSDictionary].
  factory PDTrueTypeFont(COSDictionary fontDictionary) {
    final fontDescriptorDict =
        fontDictionary.getCOSDictionary(COSName.fontDescriptor);
    TrueTypeFont? ttf;
    PDFontDescriptor? descriptor;

    if (fontDescriptorDict != null) {
      descriptor = PDFontDescriptor(fontDescriptorDict);
      final fontFile2 = descriptor.fontFile2Stream;
      if (fontFile2 != null) {
        final parser = TtfParser(isEmbedded: true);
        final view = fontFile2.createView();
        try {
          ttf = parser.parse(view);
        } finally {
          view.close();
        }
      }
    }

    if (ttf == null) {
      final baseFont = fontDictionary.getNameAsString(COSName.baseFont) ??
          fontDictionary.getNameAsString(COSName.get('BaseFont')) ??
          'TrueTypeFont';
      final mapping =
          FontMappers.instance().getTrueTypeFont(baseFont, descriptor);
      ttf = mapping.font;
      if (ttf == null) {
        throw UnimplementedError(
            'TrueType font loading without embedded FontFile2 is not supported yet.');
      }
    }

    CMapLookup? unicodeCMap;
    try {
      unicodeCMap = ttf.getUnicodeCmapLookup(isStrict: false);
    } catch (_) {
      unicodeCMap = null;
    }
    final embedder = TrueTypeEmbedder(ttf, embedSubset: false);
    final baseFont = fontDictionary.getNameAsString(COSName.baseFont) ??
      ttf.getName() ??
      'TrueTypeFont';

    final encoding = _readEncoding(fontDictionary);

    return PDTrueTypeFont._(
      fontDictionary,
      ttf,
      unicodeCMap,
      embedder,
      baseFont,
      encoding: encoding,
    );
  }

  static Encoding _readEncoding(COSDictionary dictionary) {
    final encoding = dictionary.getDictionaryObject(COSName.encoding);
    if (encoding is COSDictionary) {
      return DictionaryEncoding(encoding);
    } else if (encoding is COSName) {
      return DictionaryEncoding.resolveEncoding(encoding) ??
          WinAnsiEncoding.instance;
    }
    return WinAnsiEncoding.instance;
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
  void subset() {
    buildSubset(updateBaseFontName: true);
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

  int _glyphIdForCode(int code) {
    final unicode = toUnicode(code);
    if (unicode == null || unicode.isEmpty) {
      return 0;
    }
    final iterator = unicode.runes.iterator;
    if (!iterator.moveNext()) {
      return 0;
    }
    final cmap = _unicodeCMap;
    if (cmap == null) {
      return 0;
    }
    return cmap.getGlyphId(iterator.current);
  }

  CharStringPath _pathForGlyphId(int gid) {
    if (gid <= 0) {
      return CharStringPath();
    }
    final glyphTable = _trueTypeFont.getGlyphTable();
    if (glyphTable == null) {
      return CharStringPath();
    }
    try {
      final glyphData = glyphTable.getGlyph(gid);
      if (glyphData == null) {
        return CharStringPath();
      }
      final glyphPath = glyphData.getPath();
      if (glyphPath.isEmpty) {
        return CharStringPath();
      }
      final raw = _glyphPathToCharString(glyphPath);
      final units = _trueTypeFont.unitsPerEm;
      final scale = units > 0 && units != 1000 ? 1000.0 / units : 1.0;
      if (scale == 1.0) {
        return raw;
      }
      return _scalePath(raw, scale);
    } catch (_) {
      return CharStringPath();
    }
  }

  CharStringPath _glyphPathToCharString(ttf_glyph.GlyphPath glyphPath) {
    final path = CharStringPath();
    var currentX = 0.0;
    var currentY = 0.0;

    for (final command in glyphPath.commands) {
      if (command is ttf_glyph.MoveToCommand) {
        path.moveTo(command.x, command.y);
        currentX = command.x;
        currentY = command.y;
      } else if (command is ttf_glyph.LineToCommand) {
        path.lineTo(command.x, command.y);
        currentX = command.x;
        currentY = command.y;
      } else if (command is ttf_glyph.QuadToCommand) {
        // Convert quadratic curves to cubic Bézier.
        final x1 = currentX + (2.0 / 3.0) * (command.cx - currentX);
        final y1 = currentY + (2.0 / 3.0) * (command.cy - currentY);
        final x2 = command.x + (2.0 / 3.0) * (command.cx - command.x);
        final y2 = command.y + (2.0 / 3.0) * (command.cy - command.y);
        path.curveTo(x1, y1, x2, y2, command.x, command.y);
        currentX = command.x;
        currentY = command.y;
      } else if (command is ttf_glyph.CubicToCommand) {
        path.curveTo(
          command.cx1,
          command.cy1,
          command.cx2,
          command.cy2,
          command.x,
          command.y,
        );
        currentX = command.x;
        currentY = command.y;
      } else if (command is ttf_glyph.ClosePathCommand) {
        path.closePath();
      }
    }

    return path;
  }

  CharStringPath _scalePath(CharStringPath path, double scale) {
    if (scale == 1.0) {
      return path;
    }
    final scaled = CharStringPath();
    for (final cmd in path.commands) {
      switch (cmd) {
        case MoveToCommand(:final x, :final y):
          scaled.moveTo(x * scale, y * scale);
          break;
        case LineToCommand(:final x, :final y):
          scaled.lineTo(x * scale, y * scale);
          break;
        case CurveToCommand(
            :final x1,
            :final y1,
            :final x2,
            :final y2,
            :final x3,
            :final y3,
          ):
          scaled.curveTo(
            x1 * scale,
            y1 * scale,
            x2 * scale,
            y2 * scale,
            x3 * scale,
            y3 * scale,
          );
          break;
        case ClosePathCommand():
          scaled.closePath();
          break;
      }
    }
    return scaled;
  }

  @override
  bool hasGlyph(int code) {
    final name = codeToName(code);
    if (_fontBoxAdapter.hasGlyph(name)) {
      return true;
    }
    return _glyphIdForCode(code) > 0;
  }

  @override
  CharStringPath getPath(int code) {
    final name = codeToName(code);
    final byName = _fontBoxAdapter.getPath(name);
    if (byName.commands.isNotEmpty) {
      return byName;
    }
    return _pathForGlyphId(_glyphIdForCode(code));
  }

  @override
  CharStringPath getNormalizedPath(int code) => getPath(code);

  void _readWidths() {
    _firstChar = dictionary.getInt(COSName.firstChar) ?? 0;
    _lastChar = dictionary.getInt(COSName.lastChar) ?? 255;
    final widthsArray = dictionary.getCOSArray(COSName.widths);
    if (widthsArray != null) {
      _widths = widthsArray.toDoubleList();
    } else {
      _widths = [];
    }

    final fdDict = dictionary.getCOSDictionary(COSName.fontDescriptor);
    if (fdDict != null) {
      _fontDescriptor = PDFontDescriptor(fdDict);
    } else {
      _fontDescriptor = _createFontDescriptor();
    }

    _unitsPerEmScale = _computeUnitsPerEmScale();
    _defaultWidth = _widthForGlyphId(0) ?? 0;
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

  @override
  String? toUnicode(int code) {
    return super.toUnicode(code);
  }
}

