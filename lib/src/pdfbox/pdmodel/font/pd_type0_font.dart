import 'dart:async';
import 'dart:typed_data';

import '../../../fontbox/cff/char_string_path.dart';
import '../../../fontbox/ttf/true_type_collection.dart';
import '../../../fontbox/ttf/true_type_font.dart';
import '../../../fontbox/ttf/ttf_parser.dart';
import '../../../io/random_access_read_buffer.dart';
import '../../../io/random_access_read_buffered_file.dart';
import '../../../io/random_access_read.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_stream.dart';
import '../pd_document.dart';
import 'pd_cid_font_type2_embedder.dart';
import 'pdfont.dart';
import 'pd_vector_font.dart';
import 'type0_font.dart';
import 'cmap_manager.dart';
import '../../../fontbox/cmap/cmap.dart';
import 'cid_system_info.dart';
import 'pd_font_descriptor.dart';
import '../../../fontbox/util/bounding_box.dart';

/// Lightweight wrapper around [Type0Font] that prepares a Type 0 font dictionary.
class PDType0Font extends PDFont implements PDVectorFont {
  PDType0Font._internal(
    COSDictionary dictionary, {
    Type0Font? type0Font,
    PDCIDFontType2EmbedderResult? embedderResult,
  })  : _type0Font = type0Font,
        _cidEmbedderResult = embedderResult,
        super(dictionary);

  final Type0Font? _type0Font;
  final PDCIDFontType2EmbedderResult? _cidEmbedderResult;
  CMap? _cachedToUnicode;
  bool _triedToUnicodeLoad = false;
  CMap? _cachedEncodingCMap;
  bool _triedEncodingLoad = false;

  /// Underlying Type 0 font helper exposing CMap and CID glyph mapping.
  Type0Font get type0Font {
    final helper = _type0Font;
    if (helper == null) {
      throw StateError('Type0Font helper not available for this embedded font');
    }
    return helper;
  }

  /// Returns true when a [Type0Font] helper is attached.
  bool get hasType0FontHelper => _type0Font != null;

  /// Returns the embedder result when this font was produced from a CID subset.
  PDCIDFontType2EmbedderResult? get cidEmbedderResult => _cidEmbedderResult;

  /// Returns the font descriptor when available.
  PDFontDescriptor? get fontDescriptor => _cidEmbedderResult?.fontDescriptor;

  /// Returns the descendant font bounding box when available.
  BoundingBox? get fontBoundingBox => _type0Font?.fontBoundingBox;

  /// Returns the descendant font matrix when available.
  List<num>? get fontMatrix => _type0Font?.fontMatrix;

  /// Returns the encoding CMap if available.
  CMap? get cMap {
    final helper = _type0Font;
    if (helper != null) {
      return helper.encoding;
    }
    return _ensureEncodingCMap();
  }

  /// Returns the UCS-2 CMap when available.
  CMap? get cMapUcs2 => _type0Font?.ucs2CMap;

  /// Returns CID system information from the descendant font when available.
  CidSystemInfo? get cidSystemInfo => _type0Font?.cidSystemInfo;

  /// Indicates whether this font's encoding is a predefined CMap.
  bool get isCMapPredefined {
    final helper = _type0Font;
    if (helper != null) {
      return helper.isCMapPredefined;
    }
    final base = cosObject.getDictionaryObject(COSName.encoding);
    return base is COSName;
  }

  /// Indicates whether the descendant font belongs to the Adobe CJK collections.
  bool get isDescendantCjk => _type0Font?.isDescendantCjk ?? false;

  /// Indicates whether the font dictionary references an embedded descendant font.
  bool get isEmbedded => _cidEmbedderResult != null;

  /// Returns true when the font operates in vertical writing mode.
  bool get isVertical {
    final helper = _type0Font;
    if (helper != null) {
      return helper.encoding.wMode == 1;
    }
    final wMode = cosObject.getInt(COSName.wMode);
    if (wMode == 1) {
      return true;
    }
    final encodingName = cosObject.getNameAsString(COSName.encoding);
    return encodingName == 'Identity-V';
  }

  /// Creates a Type 0 font dictionary referencing the provided [type0Font].
  factory PDType0Font.fromType0Font({
    required String baseFont,
    required Type0Font type0Font,
  }) {
    if (baseFont.isEmpty) {
      throw ArgumentError.value(baseFont, 'baseFont');
    }

    final dictionary = COSDictionary()
      ..setName(COSName.type, 'Font')
      ..setName(COSName.subtype, COSName.type0.name)
      ..setName(COSName.baseFont, baseFont);

    final encodingName = type0Font.encoding.name;
    if (encodingName != null && encodingName.isNotEmpty) {
      dictionary.setName(COSName.encoding, encodingName);
    }

    dictionary[COSName.descendantFonts] =
        _buildDescendantFontsArray(type0Font, baseFont);

    return PDType0Font._internal(dictionary, type0Font: type0Font);
  }

  /// Embeds a TrueType font as a CIDFontType2 descendant using Identity-H encoding.
  factory PDType0Font.embedTrueTypeFont({
    required TrueTypeFont trueTypeFont,
    Iterable<int> codePoints = const <int>[],
    bool embedSubset = true,
    bool vertical = false,
  }) {
    final embedder = PDCIDFontType2Embedder(
      trueTypeFont: trueTypeFont,
      embedSubset: embedSubset,
      vertical: vertical,
    );
    for (final codePoint in codePoints) {
      embedder.addUnicode(codePoint);
    }
    final result = embedder.build();
    return PDType0Font._internal(
      result.type0Dictionary,
      embedderResult: result,
    );
  }

  /// Parses and embeds a TrueType font residing at [path].
  factory PDType0Font.fromTrueTypeFile(
    String path, {
    Iterable<int> codePoints = const <int>[],
    bool embedSubset = true,
    bool vertical = false,
    int? collectionIndex,
    String? collectionFontName,
  }) {
    final parser = TtfParser();
    final randomAccess = RandomAccessReadBufferedFile(path);
    try {
      return _embedFromRandomAccessRead(
        randomAccess,
        parser: parser,
        codePoints: codePoints,
        embedSubset: embedSubset,
        vertical: vertical,
        collectionIndex: collectionIndex,
        collectionFontName: collectionFontName,
      );
    } finally {
      randomAccess.close();
    }
  }

  /// Parses and embeds a TrueType font available as raw [bytes].
  factory PDType0Font.fromTrueTypeData(
    List<int> bytes, {
    Iterable<int> codePoints = const <int>[],
    bool embedSubset = true,
    bool vertical = false,
    int? collectionIndex,
    String? collectionFontName,
  }) {
    final parser = TtfParser();
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final randomAccess = RandomAccessReadBuffer.fromBytes(data);
    try {
      // TODO: Support incremental TrueType edits when parser is ported.
      return _embedFromRandomAccessRead(
        randomAccess,
        parser: parser,
        codePoints: codePoints,
        embedSubset: embedSubset,
        vertical: vertical,
        collectionIndex: collectionIndex,
        collectionFontName: collectionFontName,
        closeSource: false,
      );
    } finally {
      randomAccess.close();
    }
  }

  static PDType0Font loadFromFile(
    PDDocument document,
    String path, {
    Iterable<int> codePoints = const <int>[],
    bool embedSubset = true,
    bool vertical = false,
    int? collectionIndex,
    String? collectionFontName,
    TtfParser? parser,
  }) {
    _ensureDocumentOpen(document);
    final effectiveParser = parser ?? TtfParser();
    final randomAccess = RandomAccessReadBufferedFile(path);
    try {
      return _embedFromRandomAccessRead(
        randomAccess,
        parser: effectiveParser,
        codePoints: codePoints,
        embedSubset: embedSubset,
        vertical: vertical,
        collectionIndex: collectionIndex,
        collectionFontName: collectionFontName,
      );
    } finally {
      randomAccess.close();
    }
  }

  static PDType0Font loadVerticalFromFile(
    PDDocument document,
    String path, {
    Iterable<int> codePoints = const <int>[],
    bool embedSubset = true,
    int? collectionIndex,
    String? collectionFontName,
    TtfParser? parser,
  }) {
    return loadFromFile(
      document,
      path,
      codePoints: codePoints,
      embedSubset: embedSubset,
      vertical: true,
      collectionIndex: collectionIndex,
      collectionFontName: collectionFontName,
      parser: parser,
    );
  }

  static PDType0Font loadFromBytes(
    PDDocument document,
    List<int> bytes, {
    Iterable<int> codePoints = const <int>[],
    bool embedSubset = true,
    bool vertical = false,
    int? collectionIndex,
    String? collectionFontName,
    TtfParser? parser,
  }) {
    _ensureDocumentOpen(document);
    final effectiveParser = parser ?? TtfParser();
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final randomAccess = RandomAccessReadBuffer.fromBytes(data);
    try {
      return _embedFromRandomAccessRead(
        randomAccess,
        parser: effectiveParser,
        codePoints: codePoints,
        embedSubset: embedSubset,
        vertical: vertical,
        collectionIndex: collectionIndex,
        collectionFontName: collectionFontName,
        closeSource: false,
      );
    } finally {
      randomAccess.close();
    }
  }

  static PDType0Font loadVerticalFromBytes(
    PDDocument document,
    List<int> bytes, {
    Iterable<int> codePoints = const <int>[],
    bool embedSubset = true,
    int? collectionIndex,
    String? collectionFontName,
    TtfParser? parser,
  }) {
    return loadFromBytes(
      document,
      bytes,
      codePoints: codePoints,
      embedSubset: embedSubset,
      vertical: true,
      collectionIndex: collectionIndex,
      collectionFontName: collectionFontName,
      parser: parser,
    );
  }

  static Future<PDType0Font> loadFromStream(
    PDDocument document,
    Stream<List<int>> stream, {
    Iterable<int> codePoints = const <int>[],
    bool embedSubset = true,
    bool vertical = false,
    int? collectionIndex,
    String? collectionFontName,
    TtfParser? parser,
    int chunkSize = RandomAccessReadBuffer.defaultChunkSize4KB,
  }) async {
    _ensureDocumentOpen(document);
    final effectiveParser = parser ?? TtfParser();
    final buffer = await RandomAccessReadBuffer.createBufferFromStream(
      stream,
      chunkSize: chunkSize,
    );
    try {
      return _embedFromRandomAccessRead(
        buffer,
        parser: effectiveParser,
        codePoints: codePoints,
        embedSubset: embedSubset,
        vertical: vertical,
        collectionIndex: collectionIndex,
        collectionFontName: collectionFontName,
        closeSource: false,
      );
    } finally {
      buffer.close();
    }
  }

  static Future<PDType0Font> loadVerticalFromStream(
    PDDocument document,
    Stream<List<int>> stream, {
    Iterable<int> codePoints = const <int>[],
    bool embedSubset = true,
    int? collectionIndex,
    String? collectionFontName,
    TtfParser? parser,
    int chunkSize = RandomAccessReadBuffer.defaultChunkSize4KB,
  }) {
    return loadFromStream(
      document,
      stream,
      codePoints: codePoints,
      embedSubset: embedSubset,
      vertical: true,
      collectionIndex: collectionIndex,
      collectionFontName: collectionFontName,
      parser: parser,
      chunkSize: chunkSize,
    );
  }

  static PDType0Font loadFromTrueTypeFont(
    PDDocument document,
    TrueTypeFont trueTypeFont, {
    Iterable<int> codePoints = const <int>[],
    bool embedSubset = true,
    bool vertical = false,
  }) {
    _ensureDocumentOpen(document);
    return PDType0Font.embedTrueTypeFont(
      trueTypeFont: trueTypeFont,
      codePoints: codePoints,
      embedSubset: embedSubset,
      vertical: vertical,
    );
  }

  static PDType0Font loadVerticalFromTrueTypeFont(
    PDDocument document,
    TrueTypeFont trueTypeFont, {
    Iterable<int> codePoints = const <int>[],
    bool embedSubset = true,
  }) {
    return loadFromTrueTypeFont(
      document,
      trueTypeFont,
      codePoints: codePoints,
      embedSubset: embedSubset,
      vertical: true,
    );
  }

  static void _ensureDocumentOpen(PDDocument document) {
    if (document.isClosed) {
      throw StateError('PDDocument is closed');
    }
  }

  static PDType0Font _embedFromRandomAccessRead(
    RandomAccessRead source, {
    required TtfParser parser,
    required Iterable<int> codePoints,
    required bool embedSubset,
    required bool vertical,
    int? collectionIndex,
    String? collectionFontName,
    bool closeSource = true,
  }) {
    try {
      if (_looksLikeCollection(source)) {
        final collection = TrueTypeCollection.fromRandomAccessRead(
          source,
          closeAfterReading: closeSource,
        );
        TrueTypeFont? font;
        try {
          font = _selectFontFromCollection(
            collection,
            collectionIndex: collectionIndex,
            collectionFontName: collectionFontName,
          );
          return PDType0Font.embedTrueTypeFont(
            trueTypeFont: font,
            codePoints: codePoints,
            embedSubset: embedSubset,
            vertical: vertical,
          );
        } finally {
          try {
            font?.close();
          } finally {
            collection.close();
          }
        }
      }

      final font = parser.parse(source);
      try {
        return PDType0Font.embedTrueTypeFont(
          trueTypeFont: font,
          codePoints: codePoints,
          embedSubset: embedSubset,
          vertical: vertical,
        );
      } finally {
        font.close();
      }
    } finally {
      if (closeSource) {
        source.close();
      }
    }
  }

  static bool _looksLikeCollection(RandomAccessRead source) {
    final header = Uint8List(4);
    final bytesRead = source.readBuffer(header);
    if (bytesRead <= 0) {
      return false;
    }
    if (bytesRead < 4) {
      source.rewind(bytesRead);
      return false;
    }
    source.rewind(bytesRead);
    return header[0] == 0x74 && // 't'
        header[1] == 0x74 &&
        header[2] == 0x63 &&
        header[3] == 0x66;
  }

  static TrueTypeFont _selectFontFromCollection(
    TrueTypeCollection collection, {
    int? collectionIndex,
    String? collectionFontName,
  }) {
    if (collectionFontName != null) {
      final font = collection.getFontByName(collectionFontName);
      if (font == null) {
        throw ArgumentError.value(
          collectionFontName,
          'collectionFontName',
          'Font not found in collection',
        );
      }
      return font;
    }

    final targetIndex = collectionIndex ?? 0;
    return collection.getFontAtIndex(targetIndex);
  }

  static COSArray _buildDescendantFontsArray(Type0Font type0Font, String baseFont) {
    final descendant = COSDictionary()
      ..setName(COSName.type, 'Font')
      ..setName(COSName.subtype, COSName.cidFontType0.name)
      ..setName(COSName.baseFont, baseFont);

    final info = type0Font.cidSystemInfo;
    if (info != null) {
      final cidSystem = COSDictionary()
        ..setString(COSName.registry, info.registry)
        ..setString(COSName.ordering, info.ordering)
        ..setInt(COSName.supplement, info.supplement);
      descendant[COSName.cidSystemInfo] = cidSystem;
    }

    final array = COSArray();
    array.addObject(descendant);
    return array;
  }

  /// Delegates glyph decoding to the underlying [Type0Font].
  List<Type0Glyph> decodeGlyphs(Uint8List encoded) => type0Font.decodeGlyphs(encoded);

  /// Delegates CID decoding to the underlying [Type0Font].
  List<int> decodeCids(Uint8List encoded) => type0Font.decodeCids(encoded);

  /// Delegates glyph id decoding to the underlying [Type0Font].
  List<int> decodeGids(Uint8List encoded) => type0Font.decodeGids(encoded);

  /// Decodes [encoded] bytes into a Unicode string using the configured CMaps.
  String decodeToUnicode(Uint8List encoded) => type0Font.decodeToUnicode(encoded);

  @override
  String? toUnicode(int code) {
    final helper = _type0Font;
    if (helper != null) {
      for (final length in Type0Font.candidateCodeLengths(code)) {
        final glyphs = helper.decodeGlyphs(Type0Font.encodeCodeWithLength(code, length));
        if (glyphs.isNotEmpty) {
          return glyphs.first.unicode;
        }
      }
    }

    final cmap = _ensureToUnicodeCMap();
    if (cmap != null) {
      final unicode = cmap.toUnicode(code);
      if (unicode != null && unicode.isNotEmpty) {
        return unicode;
      }
    }

    return null;
  }

  @override
  double getWidthFromFont(int code) {
    final helper = _type0Font;
    if (helper == null) {
      return 0;
    }
    return helper.widthForCode(code);
  }

  /// Maps a character [code] to its CID using the available mappings.
  int codeToCid(int code) {
    final helper = _type0Font;
    if (helper != null) {
      return helper.codeToCid(code);
    }
    final cmap = cMap;
    if (cmap != null) {
      for (final length in Type0Font.candidateCodeLengths(code)) {
        final cid = cmap.toCIDWithLength(code, length);
        if (cid != 0) {
          return cid;
        }
      }
      final cid = cmap.toCIDFromInt(code);
      if (cid != 0) {
        return cid;
      }
    }
    return code;
  }

  /// Maps a character [code] to its glyph identifier.
  int codeToGid(int code) {
    final helper = _type0Font;
    if (helper != null) {
      return helper.codeToGid(code);
    }
    final result = _cidEmbedderResult;
    if (result != null && result.cidToGidMap.isNotEmpty) {
      return result.cidToGidMap[code] ?? 0;
    }
    return code;
  }

  /// Returns true when the supplied character [code] maps to a glyph.
  @override
  bool hasGlyph(int code) {
    final helper = _type0Font;
    if (helper != null) {
      return helper.hasGlyphForCode(code);
    }
    if (codeToGid(code) != 0) {
      return true;
    }
    return false;
  }

  /// Reads the next encoded character code from [input].
  int readCode(RandomAccessRead input) {
    final helper = _type0Font;
    if (helper != null) {
      return helper.readCode(input);
    }
    final cmap = cMap;
    if (cmap == null) {
      return input.read();
    }
    return cmap.readCode(input);
  }

  @override
  CharStringPath getPath(int code) {
    final helper = _type0Font;
    if (helper != null) {
      return helper.getPathForCode(code);
    }
    return CharStringPath();
  }

  @override
  CharStringPath getNormalizedPath(int code) {
    final helper = _type0Font;
    if (helper != null) {
      return helper.getNormalizedPathForCode(code);
    }
    return CharStringPath();
  }

  CMap? _ensureToUnicodeCMap() {
    if (_cachedToUnicode != null || _triedToUnicodeLoad) {
      return _cachedToUnicode;
    }
    _triedToUnicodeLoad = true;

    final base = cosObject.getDictionaryObject(COSName.toUnicode);
    if (base is COSStream) {
      final decoded = base.decode();
      if (decoded != null) {
        final buffer = RandomAccessReadBuffer.fromBytes(decoded);
        try {
          _cachedToUnicode = CMapManager.parseCMap(buffer);
        } finally {
          buffer.close();
        }
      }
    }
    return _cachedToUnicode;
  }

  CMap? _ensureEncodingCMap() {
    if (_cachedEncodingCMap != null || _triedEncodingLoad) {
      return _cachedEncodingCMap;
    }
    _triedEncodingLoad = true;

    final encoding = cosObject.getDictionaryObject(COSName.encoding);
    if (encoding is COSName) {
      _cachedEncodingCMap = CMapManager.getPredefinedCMap(encoding.name);
      return _cachedEncodingCMap;
    }
    if (encoding is COSStream) {
      final decoded = encoding.decode();
      if (decoded != null) {
        final buffer = RandomAccessReadBuffer.fromBytes(decoded);
        try {
          _cachedEncodingCMap = CMapManager.parseCMap(buffer);
        } finally {
          buffer.close();
        }
      }
    }
    return _cachedEncodingCMap;
  }
}
