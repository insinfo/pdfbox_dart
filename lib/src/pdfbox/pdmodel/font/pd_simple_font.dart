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
    print('PDSimpleFont created: ${dictionary.getNameAsString(COSName.baseFont)}, Encoding: ${encoding.runtimeType}');
    _readToUnicodeCMap();
  }

  Encoding _encoding;
  CMap? _toUnicodeCMap;

  void _readToUnicodeCMap() {
    final toUnicode = dictionary.getDictionaryObject(COSName.toUnicode);
    if (toUnicode is COSStream) {
      print('PDSimpleFont: Found ToUnicode CMap stream for ${dictionary.getNameAsString(COSName.baseFont)}');
      try {
        final parser = CMapParser();
        final view = toUnicode.createView();
        try {
          _toUnicodeCMap = parser.parse(view);
          print('PDSimpleFont: Parsed ToUnicode CMap: ${_toUnicodeCMap?.name}');
        } finally {
          view.close();
        }
      } catch (e) {
        print('PDSimpleFont: Error parsing ToUnicode CMap: $e');
      }
    }
  }

  /// Returns the encoding vector used by this font.
  Encoding get encoding => _encoding;

  set encoding(Encoding value) {
    _encoding = value;
  }

  /// Resolves the glyph name associated with a character code.
  String codeToName(int code) => _encoding.getName(code);

  /// Attempts to resolve a Unicode character for [code] using the glyph list.
  @override
  String? toUnicode(int code) {
    if (_toUnicodeCMap != null) {
      return _toUnicodeCMap!.toUnicode(code);
    }
    return glyphList.toUnicode(codeToName(code));
  }

  /// Computes the font space width for the supplied [code].
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

  /// Computes the aggregate width in font units for the provided [text].
  double getStringWidth(String text) {
    // TODO: This should also use the Widths array if available
    final metrics = standard14Metrics;
    if (metrics == null) {
      return 0;
    }
    var width = 0.0;
    for (final rune in text.runes) {
      final glyphName = glyphList.codePointToName(rune);
      var glyphWidth = metrics.getCharacterWidth(glyphName);
      if (glyphWidth == 0) {
        glyphWidth = metrics.getAverageCharacterWidth();
      }
      width += glyphWidth;
    }
    return width;
  }

  /// Suggests an encoding for standard 14 fonts based on their PostScript name.
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
