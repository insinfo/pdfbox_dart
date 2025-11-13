import '../cos/cos_base.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import '../cos/cos_stream.dart';
import 'documentinterchange/markedcontent/pd_property_list.dart';
import 'font/pd_type1_font.dart';
import 'font/standard14_fonts.dart';
import 'graphics/color/pd_color_space.dart';
import 'graphics/form/pd_form_xobject.dart';
import 'graphics/pattern/pd_abstract_pattern.dart';
import 'graphics/pd_post_script_xobject.dart';
import 'graphics/pdxobject.dart';
import 'graphics/shading/pd_shading.dart';
import 'resource_cache.dart';

/// Wraps a page/resources dictionary, mirroring PDFBox's PDResources.
class PDResources {
  PDResources([COSDictionary? dictionary, ResourceCache? resourceCache])
      : _dictionary = dictionary ?? _createDefault(),
        _resourceCache = resourceCache;

  PDResources.withCache(ResourceCache resourceCache)
      : _dictionary = _createDefault(),
        _resourceCache = resourceCache;

  final COSDictionary _dictionary;
  final ResourceCache? _resourceCache;

  COSDictionary get cosObject => _dictionary;

  ResourceCache? get resourceCache => _resourceCache;

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

  /// Resolves an XObject by name, instantiating specialised wrappers when possible.
  PDXObject? getXObject(COSName name) {
    final xObjects = _dictionary.getCOSDictionary(COSName.xObject);
    if (xObjects == null) {
      return null;
    }

    final COSBase? raw = xObjects[name];
    final COSBase? resolved = xObjects.getDictionaryObject(name);
    if (resolved == null) {
      return null;
    }

    final COSStream? stream = resolved is COSStream ? resolved : null;
    if (stream == null) {
      return null;
    }

    final cacheKey = raw ?? stream;
    final cache = _resourceCache;
    if (cache != null) {
      final cached = cache.getXObject(cacheKey);
      if (cached != null) {
        _configureXObject(cached);
        return cached;
      }
    }

    final COSName? subtype = stream.getCOSName(COSName.subtype);
    PDXObject? xObject;
    if (subtype == COSName.image) {
      xObject = PDImageXObject.fromCOSStream(stream, resources: this);
    } else if (subtype == COSName.form) {
      final form = PDFormXObject.fromCOSStream(stream);
      xObject = form;
    } else if (subtype != null) {
      if (subtype == COSName.ps) {
        xObject = PDPostScriptXObject.fromCOSStream(stream);
      } else {
        xObject = PDXObject.fromCOSStream(stream, subtype);
      }
    } else {
      return null;
    }

    _configureXObject(xObject);

    if (cache != null) {
      cache.putXObject(cacheKey, xObject);
    }
    return xObject;
  }

  /// Resolves a shading resource by name, applying caching when available.
  PDShading? getShading(COSName name) {
    final shadings = _dictionary.getCOSDictionary(COSName.shading);
    if (shadings == null) {
      return null;
    }

    final COSBase? raw = shadings[name];
    final COSDictionary? dictionary = shadings.getCOSDictionary(name);
    if (dictionary == null) {
      return null;
    }

    final cacheKey = raw ?? dictionary;
    final cache = _resourceCache;
    if (cache != null) {
      final cached = cache.getShading(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    final shading = PDShading.create(dictionary, resources: this);
    if (cache != null) {
      cache.putShading(cacheKey, shading);
    }
    return shading;
  }

  /// Resolves a pattern resource by name with cache support.
  PDAbstractPattern? getPattern(COSName name) {
    final patterns = _dictionary.getCOSDictionary(COSName.pattern);
    if (patterns == null) {
      return null;
    }

    final COSBase? raw = patterns[name];
    final COSDictionary? dictionary = patterns.getCOSDictionary(name);
    if (dictionary == null) {
      return null;
    }

    final cacheKey = raw ?? dictionary;
    final cache = _resourceCache;
    if (cache != null) {
      final cached = cache.getPattern(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    final pattern = PDAbstractPattern.create(dictionary, resources: this);
    if (cache != null) {
      cache.putPattern(cacheKey, pattern);
    }
    return pattern;
  }

  /// Resolves a property list resource (Optional Content, etc.) by name.
  PDPropertyList? getPropertyList(COSName name) {
    final properties = _dictionary.getCOSDictionary(COSName.properties);
    if (properties == null) {
      return null;
    }

    final COSBase? raw = properties[name];
    final COSDictionary? dictionary = properties.getCOSDictionary(name);
    if (dictionary == null) {
      return null;
    }

    final cacheKey = raw ?? dictionary;
    final cache = _resourceCache;
    if (cache != null) {
      final cached = cache.getPropertyList(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    final propertyList = PDPropertyList.create(dictionary);
    if (cache != null) {
      cache.putPropertyList(cacheKey, propertyList);
    }
    return propertyList;
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

  void _configureXObject(PDXObject xObject) {
    if (xObject is PDImageXObject) {
      xObject.setAssociatedResources(this);
    } else if (xObject is PDFormXObject) {
      xObject.resourceCache ??= _resourceCache;
    }
  }
}
