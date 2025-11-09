import 'dart:collection';

import '../encoding/mac_expert_encoding.dart';
import '../encoding/mac_roman_encoding.dart';
import '../encoding/symbol_encoding.dart';
import '../encoding/win_ansi_encoding.dart';
import '../encoding/zapf_dingbats_encoding.dart';
import '../resources/glyph_list_data.dart';

class GlyphList {
  GlyphList._(this.description, Map<String, List<int>> data, {GlyphList? parent}) {
    if (parent != null) {
      _nameToCodePoints.addAll(parent._nameToCodePoints);
      _nameToUnicode.addAll(parent._nameToUnicode);
      _codePointToName.addAll(parent._codePointToName);
      _unicodeToName.addAll(parent._unicodeToName);
    }

    data.forEach(_ingest);
  }

  factory GlyphList.fromHexData(String description, Map<String, List<int>> data,
          {GlyphList? parent}) =>
      GlyphList._(description, data, parent: parent);

  GlyphList extend(String description, Map<String, List<int>> data) =>
      GlyphList._(description, data, parent: this);

  final String description;
  final Map<String, List<int>> _nameToCodePoints = <String, List<int>>{};
  final Map<String, String> _nameToUnicode = <String, String>{};
  final Map<int, String> _codePointToName = <int, String>{};
  final Map<String, String> _unicodeToName = <String, String>{};
  final Map<String, String> _uniNameCache = <String, String>{};

  static final GlyphList adobeGlyphList =
      GlyphList.fromHexData('Adobe Glyph List', kAdobeGlyphListHex);

  static final GlyphList zapfDingbatsGlyphList = GlyphList.fromHexData(
    'Zapf Dingbats Glyph List',
    kZapfDingbatsGlyphListHex,
    parent: adobeGlyphList,
  );

  bool contains(String name) => _nameToCodePoints.containsKey(name);

  List<int>? codePointsForName(String name) => _nameToCodePoints[name];

  String? unicodeForName(String? name) => name == null ? null : _toUnicode(name);

  String? nameForCodePoint(int codePoint) => _codePointToName[codePoint];

  String codePointToName(int codePoint) =>
      _codePointToName[codePoint] ?? '.notdef';

  String? nameForCodePoints(List<int> codePoints) =>
      _unicodeToName[String.fromCharCodes(codePoints)];

  String sequenceToName(String value) =>
      _unicodeToName[value] ?? '.notdef';

  String nameForString(String value) => sequenceToName(value);

  Map<String, List<int>> get entries => UnmodifiableMapView(_nameToCodePoints);

  void _ingest(String name, List<int> codePoints) {
    final codes = List<int>.unmodifiable(codePoints);
    _nameToCodePoints[name] = codes;
    final unicode = String.fromCharCodes(codes);
    _nameToUnicode[name] = unicode;
    if (_isCanonicalName(name)) {
      _unicodeToName[unicode] = name;
    } else {
      _unicodeToName.putIfAbsent(unicode, () => name);
    }
    if (codes.length == 1) {
      _codePointToName.putIfAbsent(codes.first, () => name);
    }
  }

  String? _toUnicode(String name) {
    final cached = _nameToUnicode[name];
    if (cached != null) {
      return cached;
    }

    final cachedComputed = _uniNameCache[name];
    if (cachedComputed != null) {
      return cachedComputed;
    }

    String? resolved;
    final dotIndex = name.indexOf('.');
    if (dotIndex > 0) {
      resolved = _toUnicode(name.substring(0, dotIndex));
    } else if (_looksLikeUniName(name)) {
      resolved = _decodeUniName(name);
    }

    if (resolved != null) {
      _uniNameCache[name] = resolved;
    }
    return resolved;
  }

  static bool _looksLikeUniName(String name) {
    return (name.length == 7 && name.startsWith('uni')) ||
        (name.length == 5 && name.startsWith('u'));
  }

  String? _decodeUniName(String name) {
    final start = name.length == 7 ? 3 : 1;
    if (name.length < start + 4) {
      return null;
    }
    final hex = name.substring(start, start + 4);
    final codePoint = int.tryParse(hex, radix: 16);
    if (codePoint == null || (codePoint > 0xD7FF && codePoint < 0xE000)) {
      return null;
    }
    return String.fromCharCode(codePoint);
  }

  static bool _isCanonicalName(String name) {
    return WinAnsiEncoding.instance.contains(name) ||
        MacRomanEncoding.instance.contains(name) ||
        MacExpertEncoding.instance.contains(name) ||
        SymbolEncoding.instance.contains(name) ||
        ZapfDingbatsEncoding.instance.contains(name);
  }
}
