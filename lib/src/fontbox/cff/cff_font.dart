import 'dart:typed_data';

import '../../io/exceptions.dart';
import '../encoded_font.dart';
import '../font_box_font.dart';
import '../type1/type1_char_string_reader.dart';
import '../util/bounding_box.dart';
import 'cff_charset.dart';
import 'cff_encoding.dart';
import 'char_string_path.dart';
import 'cid_keyed_type2_char_string.dart';
import 'type1_char_string.dart';
import 'type2_char_string.dart';
import 'type2_char_string_parser.dart';

/// Lightweight port of PDFBox's CFF font abstractions.
abstract class CFFFont implements FontBoxFont {
  final Map<String, Object?> topDict = <String, Object?>{};

  String? _fontName;
  CFFCharset? _charset;
  CFFByteSource? _source;

  List<Uint8List> charStrings = <Uint8List>[];
  List<Uint8List> globalSubrIndex = <Uint8List>[];

  @override
  String getName() => _fontName ?? '';

  String get name => _fontName ?? '';

  set name(String value) => _fontName = value;

  CFFCharset get charset {
    final value = _charset;
    if (value == null) {
      throw StateError('Charset not initialised yet');
    }
    return value;
  }

  set charset(CFFCharset charset) => _charset = charset;

  void setByteSource(CFFByteSource source) => _source = source;

  Uint8List getData() {
    final source = _source;
    if (source == null) {
      throw StateError('Font data has not been attached');
    }
    return source.getBytes();
  }

  @override
  BoundingBox getFontBBox() {
    final list = topDict['FontBBox'];
    if (list is List) {
      final numbers = List<num>.from(list.cast<num>());
      if (numbers.length >= 4) {
        return BoundingBox.fromNumbers(numbers);
      }
    }
    throw IOException('FontBBox must have 4 numbers, but is $list');
  }

  @override
  List<num> getFontMatrix() {
    final list = topDict['FontMatrix'];
    if (list is List) {
      return List<num>.from(list.cast<num>());
    }
    return const <num>[0.001, 0.0, 0.0, 0.001, 0.0, 0.0];
  }

  int get numCharStrings => charStrings.length;
}

abstract class EncodedCFFFont extends CFFFont implements EncodedFont {
  CFFEncoding? _encoding;

  @override
  CFFEncoding? getEncoding() => _encoding;

  CFFEncoding get encoding {
    final value = _encoding;
    if (value == null) {
      throw StateError('Encoding not set');
    }
    return value;
  }

  set encoding(CFFEncoding encoding) => _encoding = encoding;
}

class CFFType1Font extends EncodedCFFFont implements Type1CharStringReader {
  final Map<String, Object?> privateDict = <String, Object?>{};

  final Map<int, Type2CharString> _charStringCache = <int, Type2CharString>{};
  Type2CharStringParser? _charStringParser;
  List<Uint8List>? _localSubrIndex;
  int? _defaultWidthX;
  int? _nominalWidthX;

  void addPrivateEntry(String name, Object? value) {
    if (value != null) {
      privateDict[name] = value;
    }
  }

  Map<String, Object?> getPrivateDict() => privateDict;

  CharStringPath getPath(String name) => getType1CharString(name).getPath();

  double getWidth(String name) => getType1CharString(name).getWidth();

  bool hasGlyph(String name) => nameToGID(name) != 0;

  @override
  Type1CharString getType1CharString(String name) {
    final gid = nameToGID(name);
    return _getType2CharString(gid, name);
  }

  Type2CharString getType2CharString(int gid) {
    final glyphName = charset.getNameForGID(gid) ?? 'GID+$gid';
    return _getType2CharString(gid, glyphName);
  }

  int nameToGID(String name) {
    final sid = charset.getSID(name);
    return charset.getGIDForSID(sid);
  }

  Type2CharString _getType2CharString(int gid, String name) {
    final normalizedGid = gid >= 0 ? gid : 0;
    final cached = _charStringCache[normalizedGid];
    if (cached != null) {
      return cached;
    }

    final bytes = (normalizedGid < charStrings.length && normalizedGid >= 0)
        ? charStrings[normalizedGid]
        : (charStrings.isNotEmpty ? charStrings.first : Uint8List(0));

    final sequence =
        _getParser().parse(bytes, globalSubrIndex, _getLocalSubrIndex());
    final type2 = Type2CharString(
      this,
      this.name,
      name,
      normalizedGid,
      sequence,
      _getDefaultWidthX(),
      _getNominalWidthX(),
    );
    _charStringCache[normalizedGid] = type2;
    return type2;
  }

  Type2CharStringParser _getParser() {
    return _charStringParser ??= Type2CharStringParser(this.name);
  }

  List<Uint8List> _getLocalSubrIndex() {
    final cached = _localSubrIndex;
    if (cached != null) {
      return cached;
    }
    final subrs = privateDict['Subrs'];
    if (subrs is List<Uint8List>) {
      _localSubrIndex = subrs;
    } else {
      _localSubrIndex = const <Uint8List>[];
    }
    return _localSubrIndex!;
  }

  int _getDefaultWidthX() {
    var value = _defaultWidthX;
    if (value != null) {
      return value;
    }
    final property = _getProperty('defaultWidthX');
    value = property is num ? property.toInt() : 1000;
    _defaultWidthX = value;
    return value;
  }

  int _getNominalWidthX() {
    var value = _nominalWidthX;
    if (value != null) {
      return value;
    }
    final property = _getProperty('nominalWidthX');
    value = property is num ? property.toInt() : 0;
    _nominalWidthX = value;
    return value;
  }

  Object? _getProperty(String name) {
    final topValue = topDict[name];
    if (topValue != null) {
      return topValue;
    }
    return privateDict[name];
  }
}

class CFFCIDFont extends CFFFont {
  String? registry;
  String? ordering;
  int supplement = 0;

  List<Map<String, Object?>> fontDicts = <Map<String, Object?>>[];
  List<Map<String, Object?>> privateDicts = <Map<String, Object?>>[];
  CFFFDSelect? fdSelect;

  final Map<int, CIDKeyedType2CharString> _charStringCache =
      <int, CIDKeyedType2CharString>{};
  Type2CharStringParser? _charStringParser;
  late final Type1CharStringReader _reader = _CidType1CharStringReader(this);

  CharStringPath getPath(String selector) {
    final cid = _selectorToCID(selector);
    return getType2CharString(cid).getPath();
  }

  double getWidth(String selector) {
    final cid = _selectorToCID(selector);
    return getType2CharString(cid).getWidth();
  }

  bool hasGlyph(String selector) {
    final cid = _selectorToCID(selector);
    return charset.getGIDForCID(cid) != 0;
  }

  CIDKeyedType2CharString getType2CharString(int cid) {
    final cached = _charStringCache[cid];
    if (cached != null) {
      return cached;
    }

    final gid = charset.getGIDForCID(cid);
    final normalizedGid = gid >= 0 ? gid : 0;
    final bytes = (normalizedGid < charStrings.length && normalizedGid >= 0)
        ? charStrings[normalizedGid]
        : (charStrings.isNotEmpty ? charStrings.first : Uint8List(0));

    final sequence = _getParser()
        .parse(bytes, globalSubrIndex, _getLocalSubrIndex(normalizedGid));
    final type2 = CIDKeyedType2CharString(
      _reader,
      name,
      cid,
      normalizedGid,
      sequence,
      _getDefaultWidthX(normalizedGid),
      _getNominalWidthX(normalizedGid),
    );
    _charStringCache[cid] = type2;
    return type2;
  }

  CharStringPath getPathForCID(int cid) => getType2CharString(cid).getPath();

  double getWidthForCID(int cid) => getType2CharString(cid).getWidth();

  bool hasCID(int cid) => charset.getGIDForCID(cid) != 0;

  Type2CharStringParser _getParser() {
    return _charStringParser ??= Type2CharStringParser(name);
  }

  List<Uint8List> _getLocalSubrIndex(int gid) {
    final selector = fdSelect;
    if (selector == null || privateDicts.isEmpty) {
      return const <Uint8List>[];
    }
    final fdIndex = selector.getFDIndex(gid);
    if (fdIndex < 0 || fdIndex >= privateDicts.length) {
      return const <Uint8List>[];
    }
    final subrs = privateDicts[fdIndex]['Subrs'];
    if (subrs is List<Uint8List>) {
      return subrs;
    }
    return const <Uint8List>[];
  }

  int _getDefaultWidthX(int gid) {
    final selector = fdSelect;
    if (selector == null || privateDicts.isEmpty) {
      return 1000;
    }
    final fdIndex = selector.getFDIndex(gid);
    if (fdIndex < 0 || fdIndex >= privateDicts.length) {
      return 1000;
    }
    final value = privateDicts[fdIndex]['defaultWidthX'];
    return value is num ? value.toInt() : 1000;
  }

  int _getNominalWidthX(int gid) {
    final selector = fdSelect;
    if (selector == null || privateDicts.isEmpty) {
      return 0;
    }
    final fdIndex = selector.getFDIndex(gid);
    if (fdIndex < 0 || fdIndex >= privateDicts.length) {
      return 0;
    }
    final value = privateDicts[fdIndex]['nominalWidthX'];
    return value is num ? value.toInt() : 0;
  }

  int _selectorToCID(String selector) {
    if (!selector.startsWith(r'\')) {
      throw ArgumentError('CID selector must begin with "\\"');
    }
    final value = selector.substring(1);
    if (value.isEmpty) {
      throw ArgumentError('CID selector missing value');
    }
    try {
      return int.parse(value);
    } on FormatException {
      throw ArgumentError('Invalid CID selector: $selector');
    }
  }
}

class _CidType1CharStringReader implements Type1CharStringReader {
  _CidType1CharStringReader(this._font);

  final CFFCIDFont _font;

  @override
  Type1CharString getType1CharString(String name) {
    if (name.startsWith(r'\')) {
      final cid = _font._selectorToCID(name);
      return _font.getType2CharString(cid);
    }
    return _font.getType2CharString(0);
  }
}

/// Provides access to the raw CFF bytes so fonts can be re-read later on demand.
abstract class CFFByteSource {
  Uint8List getBytes();
}

abstract class CFFFDSelect {
  int getFDIndex(int gid);
}
