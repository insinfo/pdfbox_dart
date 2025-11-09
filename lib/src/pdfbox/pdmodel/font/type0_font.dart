import 'dart:typed_data';

import '../../../fontbox/cff/cff_font.dart';
import '../../../fontbox/cff/cid_glyph_mapper.dart';
import '../../../fontbox/cmap/cmap.dart';
import '../../../fontbox/cmap/predefined_cmap_repository.dart';
import 'cmap_manager.dart';
import 'cid_system_info.dart';

/// Lightweight Type 0 font helper built on top of the FontBox port.
class Type0Font {
  Type0Font({
    required CFFCIDFont cidFont,
    required CMap encoding,
    CMap? toUnicode,
    int notdefCid = 0,
  })  : _cidFont = cidFont,
        _encoding = encoding,
        _toUnicode = toUnicode,
        _glyphMapper = CidGlyphMapper(cidFont, encoding, notdefCid: notdefCid) {
    _cidSystemInfo = _deriveCidSystemInfo(cidFont);
    _isCMapPredefined = _isPredefinedEncoding(_encoding);
    final info = _cidSystemInfo;
    _isDescendantCjk = info != null && _isAdobeCjkCollection(info);
    _ucs2 = _resolveUcs2Fallback();
  }

  final CFFCIDFont _cidFont;
  final CMap _encoding;
  final CMap? _toUnicode;
  final CidGlyphMapper _glyphMapper;
  late final CidSystemInfo? _cidSystemInfo;
  late final bool _isCMapPredefined;
  late final bool _isDescendantCjk;
  late final CMap? _ucs2;

  /// Returns the underlying CID font.
  CFFCIDFont get cidFont => _cidFont;

  /// Returns the encoding CMap used for CID lookups.
  CMap get encoding => _encoding;

  /// Returns the optional ToUnicode CMap.
  CMap? get toUnicodeCMap => _toUnicode;

  /// Decodes [encoded] bytes into glyph mappings.
  List<Type0Glyph> decodeGlyphs(Uint8List encoded) {
    if (encoded.isEmpty) {
      return const <Type0Glyph>[];
    }
    final mappings = _glyphMapper.mapEncoded(encoded);
    if (mappings.isEmpty) {
      return const <Type0Glyph>[];
    }
    return mappings
        .map((mapping) => Type0Glyph(
              codeUnits: mapping.codeUnits,
              cid: mapping.cid,
              gid: mapping.gid,
              width: mapping.width,
              unicode: _resolveUnicode(mapping),
            ))
        .toList(growable: false);
  }

  /// Decodes [encoded] bytes into a sequence of CIDs.
  List<int> decodeCids(Uint8List encoded) =>
      decodeGlyphs(encoded).map((glyph) => glyph.cid).toList(growable: false);

  /// Decodes [encoded] bytes into glyph ids (GIDs) recognised by the CID font.
  List<int> decodeGids(Uint8List encoded) =>
      decodeGlyphs(encoded).map((glyph) => glyph.gid).toList(growable: false);

  /// Decodes [encoded] bytes into a Unicode string using the configured CMaps.
  String decodeToUnicode(Uint8List encoded) {
    final buffer = StringBuffer();
    for (final glyph in decodeGlyphs(encoded)) {
      final unicode = glyph.unicode;
      if (unicode != null) {
        buffer.write(unicode);
      }
    }
    return buffer.toString();
  }

  String? _resolveUnicode(CidGlyphMapping mapping) {
    final toUnicode = _toUnicode;
    if (toUnicode != null) {
      final value = toUnicode.toUnicode(_codeValue(mapping.codeUnits), mapping.codeUnits.length);
      if (value != null) {
        return value;
      }
    }
    final encodingUnicode =
        _encoding.toUnicode(_codeValue(mapping.codeUnits), mapping.codeUnits.length);
    if (encodingUnicode != null) {
      return encodingUnicode;
    }
    final ucs2 = _ucs2;
    if (ucs2 != null && mapping.cid > 0) {
      final fallback = ucs2.toUnicode(mapping.cid);
      if (fallback != null) {
        return fallback;
      }
    }
    return null;
  }

  CMap? _resolveUcs2Fallback() {
    String? baseName;
    final info = _cidSystemInfo;
    if (_isDescendantCjk && info != null) {
      baseName = '${info.registry}-${info.ordering}-${info.supplement}';
    } else if (_isCMapPredefined) {
      final name = _encoding.name;
      if (name != 'Identity-H' && name != 'Identity-V') {
        baseName = name;
      }
    }
    if (baseName == null) {
      return null;
    }
    try {
      final base = CMapManager.getPredefinedCMap(baseName);
      final registry = base.registry;
      final ordering = base.ordering;
      if (registry == null || ordering == null) {
        return null;
      }
      final candidate = '$registry-$ordering-UCS2';
      if (!PredefinedCMapRepository.contains(candidate)) {
        return null;
      }
      return CMapManager.getPredefinedCMap(candidate);
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  static bool _isPredefinedEncoding(CMap cmap) {
    final name = cmap.name;
    if (name == null) {
      return false;
    }
    return PredefinedCMapRepository.contains(name);
  }

  static CidSystemInfo? _deriveCidSystemInfo(CFFCIDFont cidFont) {
    final registry = cidFont.registry;
    final ordering = cidFont.ordering;
    final supplement = cidFont.supplement;
    if (registry == null || ordering == null) {
      return null;
    }
    return CidSystemInfo(registry: registry, ordering: ordering, supplement: supplement);
  }

  static bool _isAdobeCjkCollection(CidSystemInfo info) {
    if (info.registry != 'Adobe') {
      return false;
    }
    switch (info.ordering) {
      case 'GB1':
      case 'CNS1':
      case 'Japan1':
      case 'Korea1':
        return true;
      default:
        return false;
    }
  }

  int _codeValue(Uint8List codeUnits) => CMap.toInt(codeUnits);
}

/// Represents a decoded glyph produced by [Type0Font].
class Type0Glyph extends CidGlyphMapping {
  Type0Glyph({
    required Uint8List codeUnits,
    required int cid,
    required int gid,
    required double width,
    this.unicode,
  }) : super(codeUnits, cid, gid, width);

  /// Unicode value associated with this glyph, when available.
  final String? unicode;

  @override
  String toString() {
    final hex = codeUnits.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final unicodeDisplay = unicode == null ? 'null' : _escapeUnicode(unicode!);
    return 'Type0Glyph(code=0x$hex, cid=$cid, gid=$gid, width=$width, unicode=$unicodeDisplay)';
  }

  static String _escapeUnicode(String value) {
    final buffer = StringBuffer();
    for (final codePoint in value.runes) {
      if (codePoint >= 0x20 && codePoint <= 0x7e && codePoint != 0x5c) {
        buffer.writeCharCode(codePoint);
      } else {
        buffer.write('\\u${codePoint.toRadixString(16).padLeft(4, '0')}');
      }
    }
    return buffer.toString();
  }
}
