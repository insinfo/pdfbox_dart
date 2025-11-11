import '../cos/cos_base.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import 'font/pd_type1_font.dart';
import 'font/standard14_fonts.dart';
import 'graphics/color/pd_color_space.dart';

/// Wraps a page/resources dictionary, mirroring PDFBox's PDResources.
class PDResources {
  PDResources([COSDictionary? dictionary])
      : _dictionary = dictionary ?? _createDefault();

  final COSDictionary _dictionary;

  COSDictionary get cosObject => _dictionary;

  bool get hasFontResources =>
      _dictionary.getCOSDictionary(COSName.font) != null;

  bool get hasColorSpaceResources =>
      _dictionary.getCOSDictionary(COSName.colorSpace) != null;

  Iterable<COSName> get fontNames {
    final fonts = _dictionary.getCOSDictionary(COSName.font);
    if (fonts == null) {
      return const <COSName>[];
    }
    return fonts.entries.map((entry) => entry.key);
  }

  COSDictionary? getFont(COSName name) {
    final fonts = _dictionary.getCOSDictionary(COSName.font);
    return fonts?.getCOSDictionary(name);
  }

  void setFont(COSName name, COSDictionary fontDictionary) {
    final fonts = _ensureFontDictionary();
    fonts[name] = fontDictionary;
  }

  void removeFont(COSName name) {
    final fonts = _dictionary.getCOSDictionary(COSName.font);
    if (fonts == null) {
      return;
    }
    fonts.removeItem(name);
    if (fonts.isEmpty) {
      _dictionary.removeItem(COSName.font);
    }
  }

  COSDictionary registerStandard14Font(
    COSName resourceName,
    String baseFont, {
    String encoding = 'WinAnsiEncoding',
  }) {
    if (baseFont.isEmpty) {
      throw ArgumentError.value(baseFont, 'baseFont');
    }
    final standardFont = Standard14Fonts.byPostScriptName(baseFont);
    if (standardFont != null) {
      final pdFont = PDType1Font.standard14(standardFont);
      setFont(resourceName, pdFont.cosObject);
      return pdFont.cosObject;
    }
    final font = COSDictionary()
      ..setName(COSName.type, 'Font')
      ..setName(COSName.subtype, COSName.type1.name)
      ..setName(COSName.baseFont, baseFont);
    if (encoding.isNotEmpty) {
      font.setName(COSName.encoding, encoding);
    }
    setFont(resourceName, font);
    return font;
  }

  static COSDictionary _createDefault() {
    final dict = COSDictionary();
    return dict;
  }

  bool hasColorSpace(COSName name) {
    final colorSpaces = _dictionary.getCOSDictionary(COSName.colorSpace);
    return colorSpaces?.containsKey(name) ?? false;
  }

  COSBase? getColorSpaceObject(COSName name) {
    final colorSpaces = _dictionary.getCOSDictionary(COSName.colorSpace);
    return colorSpaces?.getDictionaryObject(name);
  }

  COSBase? getDefaultColorSpaceObject(COSName name) =>
      _dictionary.getDictionaryObject(name);

  PDColorSpace? getColorSpace(COSName name) {
    final value = getColorSpaceObject(name);
    if (value == null) {
      return null;
    }
    return PDColorSpace.create(value, resources: this);
  }

  void setColorSpace(COSName name, COSBase colorSpace) {
    final colorSpaces = _ensureColorSpaceDictionary();
    colorSpaces[name] = colorSpace;
  }

  void removeColorSpace(COSName name) {
    final colorSpaces = _dictionary.getCOSDictionary(COSName.colorSpace);
    colorSpaces?.removeItem(name);
    if (colorSpaces != null && colorSpaces.isEmpty) {
      _dictionary.removeItem(COSName.colorSpace);
    }
  }

  COSDictionary _ensureFontDictionary() {
    final existing = _dictionary.getCOSDictionary(COSName.font);
    if (existing != null) {
      return existing;
    }
    final fonts = COSDictionary();
    _dictionary[COSName.font] = fonts;
    return fonts;
  }

  COSDictionary _ensureColorSpaceDictionary() {
    final existing = _dictionary.getCOSDictionary(COSName.colorSpace);
    if (existing != null) {
      return existing;
    }
    final spaces = COSDictionary();
    _dictionary[COSName.colorSpace] = spaces;
    return spaces;
  }
}
