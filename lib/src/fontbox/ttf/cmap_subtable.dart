import 'dart:collection';
import 'dart:math';

import '../io/ttf_data_stream.dart';
import 'cmap_lookup.dart';

/// Implementação da subtable `cmap`, responsável por mapear codepoints para
/// glyph IDs em fontes TrueType/OpenType. Atualmente suporta os formatos 0, 4,
/// 6 e 12, que cobrem a grande maioria dos casos encontrados no PDFBox.
class CmapSubtable implements CMapLookup {
  static const int _multipleMarker = -0x80000000;

  final Map<int, List<int>> _glyphIdToCharacterCodeMultiple = <int, List<int>>{};
  Map<int, int> _characterCodeToGlyphId = <int, int>{};
  List<int>? _glyphIdToCharacterCode;

  int _platformId = 0;
  int _platformEncodingId = 0;
  int _format = -1;
  int _language = 0;
  int _length = 0;
  int _version = 0;
  int _subTableOffset = 0;

  void initData(TtfDataStream data) {
    _platformId = data.readUnsignedShort();
    _platformEncodingId = data.readUnsignedShort();
    _subTableOffset = data.readUnsignedInt();
  }

  void initSubtable(int tableOffset, int numGlyphs, TtfDataStream data) {
    data.seek(tableOffset + _subTableOffset);
    _format = data.readUnsignedShort();
    if (_format < 8) {
      _length = data.readUnsignedShort();
      _language = data.readUnsignedShort();
      _version = _language;
    } else {
      data.readUnsignedShort();
      _length = data.readUnsignedInt();
      _version = data.readUnsignedInt();
      _language = 0;
    }

    switch (_format) {
      case 0:
        _processFormat0(data);
        break;
      case 4:
        _processFormat4(data, numGlyphs);
        break;
      case 6:
        _processFormat6(data);
        break;
      case 12:
        _processFormat12(data, numGlyphs);
        break;
      default:
        throw UnsupportedError('cmap format $_format ainda não implementado');
    }
  }

  void addMapping(int codePoint, int glyphId) {
    final previousGlyph = _characterCodeToGlyphId[codePoint];
    if (previousGlyph != null && previousGlyph != glyphId) {
      _detachCodePointFromGlyph(previousGlyph, codePoint);
    }
    _characterCodeToGlyphId[codePoint] = glyphId;

    _ensureGlyphCapacity(glyphId + 1);
    final current = _glyphIdToCharacterCode![glyphId];
    if (current == -1) {
      _glyphIdToCharacterCode![glyphId] = codePoint;
    } else if (current == _multipleMarker) {
      final codes = _glyphIdToCharacterCodeMultiple.putIfAbsent(glyphId, () => <int>[]);
      if (!codes.contains(codePoint)) {
        codes.add(codePoint);
        codes.sort();
      }
    } else if (current != codePoint) {
      final codes = _glyphIdToCharacterCodeMultiple.putIfAbsent(glyphId, () => <int>[current]);
      if (!codes.contains(codePoint)) {
        codes.add(codePoint);
      }
      codes.sort();
      _glyphIdToCharacterCode![glyphId] = _multipleMarker;
    }
  }

  void removeMapping(int codePoint) {
    final glyphId = _characterCodeToGlyphId.remove(codePoint);
    if (glyphId == null) {
      return;
    }
    _detachCodePointFromGlyph(glyphId, codePoint);
  }

  void copyFrom(CmapSubtable other) {
    for (final entry in other._characterCodeToGlyphId.entries) {
      addMapping(entry.key, entry.value);
    }
  }

  Map<int, int> get characterCodeToGlyphId => UnmodifiableMapView(_characterCodeToGlyphId);

  bool get isEmpty => _characterCodeToGlyphId.isEmpty;

  int get mappingCount => _characterCodeToGlyphId.length;

  int get platformId => _platformId;
  int get platformEncodingId => _platformEncodingId;
  int get format => _format;
  int get language => _language;
  int get length => _length;
  int get version => _version;
  int get subTableOffset => _subTableOffset;

  @override
  int getGlyphId(int codePoint) => _characterCodeToGlyphId[codePoint] ?? 0;

  @override
  List<int>? getCharCodes(int glyphId) {
    final codes = _glyphIdToCharacterCode;
    if (glyphId < 0 || codes == null || glyphId >= codes.length) {
      return null;
    }
    final value = codes[glyphId];
    if (value == -1) {
      return null;
    }
    if (value == _multipleMarker) {
      final mapped = _glyphIdToCharacterCodeMultiple[glyphId];
      if (mapped == null || mapped.isEmpty) {
        return null;
      }
      final ordered = List<int>.from(mapped)..sort();
      return List<int>.unmodifiable(ordered);
    }
    return List<int>.unmodifiable(<int>[value]);
  }

  void _processFormat0(TtfDataStream data) {
    _resetMappings();
    final glyphMapping = data.readBytes(256);
    _glyphIdToCharacterCode = _newGlyphIdToCharacterCode(256);
    for (var i = 0; i < glyphMapping.length; i++) {
      final glyphIndex = glyphMapping[i] & 0xff;
      _ensureGlyphCapacity(glyphIndex + 1);
      _glyphIdToCharacterCode![glyphIndex] = i;
      _characterCodeToGlyphId[i] = glyphIndex;
    }
  }

  void _processFormat4(TtfDataStream data, int numGlyphs) {
    _resetMappings();
    final segCountX2 = data.readUnsignedShort();
    final segCount = segCountX2 ~/ 2;
    data.readUnsignedShort();
    data.readUnsignedShort();
    data.readUnsignedShort();

    final endCount = data.readUnsignedShortArray(segCount);
    data.readUnsignedShort();
    final startCount = data.readUnsignedShortArray(segCount);
    final idDelta = data.readUnsignedShortArray(segCount);
    final idRangeOffsetPosition = data.currentPosition;
    final idRangeOffset = data.readUnsignedShortArray(segCount);

    var maxGlyphId = 0;

    for (var i = 0; i < segCount; i++) {
      final start = startCount[i];
      final end = endCount[i];
      final delta = idDelta[i];
      final rangeOffset = idRangeOffset[i];
      final segmentRangeOffset = idRangeOffsetPosition + (i * 2) + rangeOffset;

      if (start == 0xFFFF && end == 0xFFFF) {
        continue;
      }

      for (var code = start; code <= end; code++) {
        int? glyphIndex;
        if (rangeOffset == 0) {
          glyphIndex = (code + delta) & 0xFFFF;
        } else {
          final glyphOffset = segmentRangeOffset + ((code - start) * 2);
          data.seek(glyphOffset);
          final rawGlyph = data.readUnsignedShort();
          if (rawGlyph == 0) {
            continue;
          }
          glyphIndex = (rawGlyph + delta) & 0xFFFF;
        }
        if (glyphIndex == null) {
          continue;
        }
        maxGlyphId = max(maxGlyphId, glyphIndex);
        _characterCodeToGlyphId[code] = glyphIndex;
      }
    }

    if (_characterCodeToGlyphId.isEmpty) {
      return;
    }
    _buildGlyphIdToCharacterCodeLookup(maxGlyphId);
  }

  void _processFormat6(TtfDataStream data) {
    _resetMappings();
    final firstCode = data.readUnsignedShort();
    final entryCount = data.readUnsignedShort();
    if (entryCount == 0) {
      return;
    }
    final glyphIdArray = data.readUnsignedShortArray(entryCount);
    var maxGlyphId = 0;
    for (var i = 0; i < entryCount; i++) {
      final glyphId = glyphIdArray[i];
      maxGlyphId = max(maxGlyphId, glyphId);
      _characterCodeToGlyphId[firstCode + i] = glyphId;
    }
    _buildGlyphIdToCharacterCodeLookup(maxGlyphId);
  }

  void _processFormat12(TtfDataStream data, int numGlyphs) {
    _resetMappings();
    final groupCount = data.readUnsignedInt();
    var maxGlyphId = 0;
    for (var i = 0; i < groupCount; i++) {
      final firstCode = data.readUnsignedInt();
      final endCode = data.readUnsignedInt();
      final startGlyph = data.readUnsignedInt();

      for (var offset = 0; offset <= endCode - firstCode; offset++) {
        final glyphId = startGlyph + offset;
        if (glyphId >= numGlyphs) {
          break;
        }
        maxGlyphId = max(maxGlyphId, glyphId);
        _characterCodeToGlyphId[firstCode + offset] = glyphId;
      }
    }
    if (_characterCodeToGlyphId.isNotEmpty) {
      _buildGlyphIdToCharacterCodeLookup(maxGlyphId);
    }
  }

  void _buildGlyphIdToCharacterCodeLookup(int maxGlyphId) {
    _glyphIdToCharacterCode = _newGlyphIdToCharacterCode(maxGlyphId + 1);
    _glyphIdToCharacterCodeMultiple.clear();
    _characterCodeToGlyphId.forEach((codePoint, glyphId) {
      _ensureGlyphCapacity(glyphId + 1);
      final current = _glyphIdToCharacterCode![glyphId];
      if (current == -1) {
        _glyphIdToCharacterCode![glyphId] = codePoint;
      } else {
        final list = _glyphIdToCharacterCodeMultiple.putIfAbsent(glyphId, () => <int>[]);
        if (current != _multipleMarker) {
          list.add(current);
          _glyphIdToCharacterCode![glyphId] = _multipleMarker;
        }
        if (!list.contains(codePoint)) {
          list.add(codePoint);
        }
      }
    });
    for (final list in _glyphIdToCharacterCodeMultiple.values) {
      list.sort();
    }
  }

  void _resetMappings() {
    _glyphIdToCharacterCode = null;
    _glyphIdToCharacterCodeMultiple.clear();
    _characterCodeToGlyphId = <int, int>{};
  }

  void _ensureGlyphCapacity(int size) {
    final current = _glyphIdToCharacterCode;
    if (current == null) {
      _glyphIdToCharacterCode = _newGlyphIdToCharacterCode(size);
      return;
    }
    if (current.length >= size) {
      return;
    }
    final expanded = _newGlyphIdToCharacterCode(size);
    for (var i = 0; i < current.length; i++) {
      expanded[i] = current[i];
    }
    _glyphIdToCharacterCode = expanded;
  }

  void _detachCodePointFromGlyph(int glyphId, int codePoint) {
    final codes = _glyphIdToCharacterCode;
    if (codes == null || glyphId < 0 || glyphId >= codes.length) {
      return;
    }
    final current = codes[glyphId];
    if (current == _multipleMarker) {
      final list = _glyphIdToCharacterCodeMultiple[glyphId];
      if (list == null) {
        return;
      }
      list.remove(codePoint);
      if (list.isEmpty) {
        _glyphIdToCharacterCodeMultiple.remove(glyphId);
        codes[glyphId] = -1;
      } else if (list.length == 1) {
        codes[glyphId] = list.first;
        _glyphIdToCharacterCodeMultiple.remove(glyphId);
      }
    } else if (current == codePoint) {
      codes[glyphId] = -1;
    }
  }

  List<int> _newGlyphIdToCharacterCode(int size) => List<int>.filled(size, -1);
}
