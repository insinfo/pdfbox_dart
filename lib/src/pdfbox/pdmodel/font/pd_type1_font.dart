import '../../../fontbox/encoding/encoding.dart';
import '../../../fontbox/encoding/symbol_encoding.dart';
import '../../../fontbox/encoding/win_ansi_encoding.dart';
import '../../../fontbox/encoding/zapf_dingbats_encoding.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'encoding/glyph_list.dart';
import 'pd_simple_font.dart';
import 'standard14_fonts.dart';
import 'encoding/dictionary_encoding.dart';

/// Lightweight implementation of PDFBox's PDType1Font focused on creation scenarios.
class PDType1Font extends PDSimpleFont {
  PDType1Font._(
    COSDictionary dictionary, {
    required Encoding encoding,
    required GlyphList glyphList,
    Standard14Font? standard14Font,
  }) : super(
          dictionary,
          encoding: encoding,
          glyphList: glyphList,
          standard14Font: standard14Font,
        );

  factory PDType1Font(COSDictionary dictionary) {
    final encoding = _readEncoding(dictionary);
    final glyphList = _readGlyphList(dictionary);
    return PDType1Font._(
      dictionary,
      encoding: encoding,
      glyphList: glyphList,
    );
  }

  /// Creates an instance representing one of the PDF standard 14 Type 1 fonts.
  factory PDType1Font.standard14(Standard14Font font) {
    final dictionary = COSDictionary()
      ..setName(COSName.type, 'Font')
      ..setName(COSName.subtype, COSName.type1.name)
      ..setName(COSName.baseFont, font.postScriptName);

    final encoding = _encodingForStandard14(font.postScriptName);
    final glyphList = _glyphListForStandard14(font.postScriptName);
    if (encoding == WinAnsiEncoding.instance) {
      dictionary.setName(COSName.encoding, 'WinAnsiEncoding');
    }
    return PDType1Font._(
      dictionary,
      encoding: encoding,
      glyphList: glyphList,
      standard14Font: font,
    );
  }

  /// Creates an instance representing the Helvetica standard 14 font.
  factory PDType1Font.helvetica() {
    return PDType1Font.standard14(
      Standard14Fonts.byPostScriptName('Helvetica')!,
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
    final baseFont = dictionary.getNameAsString(COSName.baseFont);
    if (baseFont != null) {
      return _encodingForStandard14(baseFont);
    }
    return WinAnsiEncoding.instance;
  }

  static GlyphList _readGlyphList(COSDictionary dictionary) {
    final baseFont = dictionary.getNameAsString(COSName.baseFont);
    if (baseFont != null) {
      return _glyphListForStandard14(baseFont);
    }
    return GlyphList.getAdobeGlyphList();
  }

  static Encoding _encodingForStandard14(String name) {
    switch (name) {
      case 'Symbol':
        return SymbolEncoding.instance;
      case 'ZapfDingbats':
        return ZapfDingbatsEncoding.instance;
      default:
        return WinAnsiEncoding.instance;
    }
  }

  static GlyphList _glyphListForStandard14(String name) {
    switch (name) {
      case 'ZapfDingbats':
        return GlyphList.getZapfDingbats();
      default:
        return GlyphList.getAdobeGlyphList();
    }
  }
}
