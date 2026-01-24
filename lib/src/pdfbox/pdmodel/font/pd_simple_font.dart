import 'dart:typed_data';

import '../../../fontbox/encoding/encoding.dart';
import '../../../fontbox/encoding/symbol_encoding.dart';
import '../../../fontbox/encoding/win_ansi_encoding.dart';
import '../../../fontbox/encoding/zapf_dingbats_encoding.dart';
import '../../../fontbox/cmap/cmap.dart';
import '../../../fontbox/cmap/cmap_parser.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_number.dart';
import '../../cos/cos_stream.dart';
import 'encoding/glyph_list.dart';
import 'pdfont.dart';
import 'standard14_fonts.dart';

/// Base implementation for simple fonts (Type 1, TrueType).
abstract class PDSimpleFont extends PDFont {
  PDSimpleFont(
    COSDictionary dictionary, {
    required Encoding encoding,
    GlyphList? glyphList,
    Standard14Font? standard14Font,
  })  : _encoding = encoding,
        super(dictionary, standard14Font: standard14Font) {
    this.glyphList = glyphList ?? GlyphList.getAdobeGlyphList();
    _readToUnicodeCMap();
  }

  Encoding _encoding;
  CMap? _toUnicodeCMap;

  @override
  CMap? get toUnicodeCMap => _toUnicodeCMap;

  void _readToUnicodeCMap() {
    final toUnicode = dictionary.getDictionaryObject(COSName.toUnicode);
    if (toUnicode is COSStream) {
      try {
        final parser = CMapParser();
        final view = toUnicode.createView();
        try {
          _toUnicodeCMap = parser.parse(view);
        } finally {
          view.close();
        }
      } catch (_) {
        // Ignore malformed ToUnicode streams; callers will fall back.
      }
    }
  }

  /// Returns the encoding vector used by this font.
  Encoding get encoding => _encoding;

  set encoding(Encoding value) {
    _encoding = value;
  }

  /// Resolves the glyph name associated with a character code (0..255).
  String codeToName(int code) => _encoding.getName(code);

  /// Attempts to resolve a Unicode character for [code] using ToUnicode, else glyph list.
  @override
  String? toUnicode(int code) {
    if (_toUnicodeCMap != null) {
      return _toUnicodeCMap!.toUnicode(code);
    }
    return glyphList.toUnicode(codeToName(code));
  }

  @override
  double getWidthFromFont(int code) {
    final firstChar = dictionary.getInt(COSName.firstChar);
    final lastChar = dictionary.getInt(COSName.lastChar);
    final widths = dictionary.getCOSArray(COSName.widths);

    if (widths != null && firstChar != null && lastChar != null) {
      final index = code - firstChar;
      if (index >= 0 && index < widths.length) {
        final w = widths.getObject(index);
        if (w is COSNumber) {
          return w.doubleValue;
        }
      }
    }

    final metrics = standard14Metrics;
    if (metrics != null) {
      final glyphName = codeToName(code);
      var width = metrics.getCharacterWidth(glyphName);
      if (width == 0) {
        width = metrics.getCharacterWidth('.notdef');
        if (width == 0) {
          width = metrics.getAverageCharacterWidth();
        }
      }
      return width;
    }

    return 0;
  }

  /// CORRETO: largura calculada a partir dos *códigos* (bytes) do content stream.
  double getStringWidthFromBytes(Uint8List codes) {
    var width = 0.0;
    for (final code in codes) {
      width += getWidthFromFont(code);
    }
    return width;
  }

  // Wrapper: use APENAS quando você tem uma "string de bytes" (latin1).
  // Se treatAsLatin1Bytes=false, fazemos fallback "safe" (invalid vira '?').
  @override
  double getStringWidth(
    String text, {
    bool treatAsLatin1Bytes = true,
  }) {
    if (treatAsLatin1Bytes) {
      final codes = Uint8List(text.length);
      for (var i = 0; i < text.length; i++) {
        codes[i] = text.codeUnitAt(i) & 0xFF;
      }
      return getStringWidthFromBytes(codes);
    }

    // Fallback: Unicode -> Latin1 (invalid -> '?')
    final codes = Uint8List.fromList(text.codeUnits.map((u) => u > 255 ? 63 : u).toList());
    return getStringWidthFromBytes(codes);
  }

  static Encoding encodingForStandard14(String postScriptName) {
    switch (postScriptName) {
      case 'ZapfDingbats':
        return ZapfDingbatsEncoding.instance;
      case 'Symbol':
        return SymbolEncoding.instance;
      default:
        return WinAnsiEncoding.instance;
    }
  }
}
