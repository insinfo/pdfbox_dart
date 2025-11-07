import 'dart:collection';
import 'dart:math';

import 'package:pdfbox_dart/src/io/exceptions.dart';

import '../io/ttf_data_stream.dart';
import 'cmap_lookup.dart';

/// Implementação da subtable `cmap`, responsável por mapear codepoints para
/// glyph IDs em fontes TrueType/OpenType. Atualmente suporta os formatos 0, 2,
/// 4, 6, 8, 10, 12, 13 e 14, que cobrem a grande maioria dos casos encontrados
/// no PDFBox.
class CmapSubtable implements CMapLookup {
  static const int _multipleMarker = -0x80000000;
  static const int _leadOffset = 0xD800 - (0x10000 >> 10);
  static const int _surrogateOffset = 0x10000 - (0xD800 << 10) - 0xDC00;

  final Map<int, List<int>> _glyphIdToCharacterCodeMultiple =
      <int, List<int>>{};
  Map<int, int> _characterCodeToGlyphId = <int, int>{};
  List<int>? _glyphIdToCharacterCode;
  final Map<int, List<_VariationRange>> _variationDefaultRanges =
      <int, List<_VariationRange>>{};
  final Map<int, Map<int, int>> _variationGlyphMappings =
      <int, Map<int, int>>{};

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
    final subtableStart = tableOffset + _subTableOffset;
    data.seek(subtableStart);
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
      case 2:
        _processFormat2(data, numGlyphs);
        break;
      case 4:
        _processFormat4(data, numGlyphs);
        break;
      case 6:
        _processFormat6(data);
        break;
      case 8:
        _processFormat8(data, numGlyphs);
        break;
      case 10:
        _processFormat10(data, numGlyphs);
        break;
      case 12:
        _processFormat12(data, numGlyphs);
        break;
      case 13:
        _processFormat13(data, numGlyphs);
        break;
      case 14:
        _processFormat14(data, subtableStart, _version);
        break;
      default:
        throw UnsupportedError('cmap format $_format ainda não implementado');
    }
  }

  void _processFormat2(TtfDataStream data, int numGlyphs) {
    _resetMappings();

    var maxSubHeaderIndex = 0;
    for (var i = 0; i < 256; i++) {
      final key = data.readUnsignedShort();
      maxSubHeaderIndex = max(maxSubHeaderIndex, key ~/ 8);
    }

    final subHeaderCount = maxSubHeaderIndex + 1;
    final subHeaders = List<_Format2SubHeader?>.filled(subHeaderCount, null);
    for (var i = 0; i < subHeaderCount; i++) {
      final firstCode = data.readUnsignedShort();
      final entryCount = data.readUnsignedShort();
      final idDelta = data.readSignedShort();
      final rawOffset = data.readUnsignedShort();
      final idRangeOffset = rawOffset -
          ((subHeaderCount - i - 1) * 8) -
          2; // ajusta para início do array
      subHeaders[i] = _Format2SubHeader(
        firstCode: firstCode,
        entryCount: entryCount,
        idDelta: idDelta,
        idRangeOffset: idRangeOffset,
      );
    }

    final glyphArrayStart = data.currentPosition;
    var maxGlyphId = 0;

    if (numGlyphs == 0) {
      return;
    }

    for (var i = 0; i < subHeaderCount; i++) {
      final header = subHeaders[i];
      if (header == null || header.entryCount == 0) {
        continue;
      }

      data.seek(glyphArrayStart + header.idRangeOffset);
      for (var j = 0; j < header.entryCount; j++) {
        final rawGlyphId = data.readUnsignedShort();
        if (rawGlyphId == 0) {
          continue;
        }

        final glyphId = (rawGlyphId + header.idDelta) & 0xFFFF;
        if (glyphId >= numGlyphs) {
          continue;
        }

        final charCode = (i << 8) + header.firstCode + j;
        _characterCodeToGlyphId[charCode] = glyphId;
        maxGlyphId = max(maxGlyphId, glyphId);
      }
    }

    if (_characterCodeToGlyphId.isNotEmpty) {
      _buildGlyphIdToCharacterCodeLookup(maxGlyphId);
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
      final codes =
          _glyphIdToCharacterCodeMultiple.putIfAbsent(glyphId, () => <int>[]);
      if (!codes.contains(codePoint)) {
        codes.add(codePoint);
        codes.sort();
      }
    } else if (current != codePoint) {
      final codes = _glyphIdToCharacterCodeMultiple.putIfAbsent(
          glyphId, () => <int>[current]);
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

  Map<int, int> get characterCodeToGlyphId =>
      UnmodifiableMapView(_characterCodeToGlyphId);
  Map<int, Map<int, int>> get variationGlyphMappings {
    final result = <int, Map<int, int>>{};
    _variationGlyphMappings.forEach((selector, map) {
      result[selector] = UnmodifiableMapView(map);
    });
    return UnmodifiableMapView(result);
  }

  /// Combina dados de variação de outro subtable (formato 14) neste cmap.
  void mergeVariationData(CmapSubtable other) {
    if (identical(this, other)) {
      return;
    }
    if (other._variationDefaultRanges.isEmpty &&
        other._variationGlyphMappings.isEmpty) {
      return;
    }

    other._variationDefaultRanges.forEach((selector, ranges) {
      final target = _variationDefaultRanges.putIfAbsent(
          selector, () => <_VariationRange>[]);
      for (final range in ranges) {
        target.add(_VariationRange(range.start, range.end));
      }
      if (target.length > 1) {
        _normalizeVariationRanges(target);
      }
    });

    other._variationGlyphMappings.forEach((selector, mapping) {
      final target =
          _variationGlyphMappings.putIfAbsent(selector, () => <int, int>{});
      target.addAll(mapping);
    });
  }

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
  @override
  int getGlyphId(int codePoint, [int? variationSelector]) {
    final baseGlyph = _baseGlyphId(codePoint);
    if (variationSelector == null) {
      return baseGlyph;
    }

    final explicit = _variationGlyphMappings[variationSelector]?[codePoint];
    if (explicit != null) {
      return explicit;
    }

    if (isDefaultVariation(codePoint, variationSelector)) {
      return baseGlyph;
    }

    return baseGlyph;
  }

  /// Mapeia uma sequência de codepoints em glyph IDs, consumindo seletores de
  /// variação associados ao caractere anterior quando presentes.
  List<int> mapCodePoints(Iterable<int> codePoints) {
    final source = codePoints is List<int>
        ? codePoints
        : List<int>.from(codePoints, growable: false);
    final glyphIds = <int>[];

    for (var index = 0; index < source.length; index++) {
      final codePoint = source[index];
      if (isVariationSelector(codePoint)) {
        // Seletores isolados são ignorados, conforme recomenda a especificação.
        continue;
      }

      int? variationSelector;
      if (index + 1 < source.length && isVariationSelector(source[index + 1])) {
        variationSelector = source[index + 1];
        index++;
      }

      glyphIds.add(getGlyphId(codePoint, variationSelector));
    }

    return glyphIds;
  }

  static bool isVariationSelector(int codePoint) {
    if (codePoint >= 0xFE00 && codePoint <= 0xFE0F) {
      return true;
    }
    return codePoint >= 0xE0100 && codePoint <= 0xE01EF;
  }

  void _normalizeVariationRanges(List<_VariationRange> ranges) {
    ranges.sort((a, b) => a.start.compareTo(b.start));
    var index = 0;
    while (index < ranges.length - 1) {
      final current = ranges[index];
      final next = ranges[index + 1];
      if (next.start <= current.end + 1) {
        final merged = _VariationRange(
          current.start,
          max(current.end, next.end),
        );
        ranges[index] = merged;
        ranges.removeAt(index + 1);
      } else {
        index++;
      }
    }
  }

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

  int _baseGlyphId(int codePoint) => _characterCodeToGlyphId[codePoint] ?? 0;

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
        late final int glyphIndex;
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
        maxGlyphId = max(maxGlyphId, glyphIndex);
        _characterCodeToGlyphId[code] = glyphIndex;
      }
    }

    if (_characterCodeToGlyphId.isEmpty) {
      return;
    }
    _buildGlyphIdToCharacterCodeLookup(maxGlyphId);
  }

  void _processFormat14(
      TtfDataStream data, int subtableStart, int selectorCount) {
    _resetMappings();
    _variationDefaultRanges.clear();
    _variationGlyphMappings.clear();

    for (var i = 0; i < selectorCount; i++) {
      final variationSelector = _readUInt24(data);
      final defaultOffset = data.readUnsignedInt();
      final nonDefaultOffset = data.readUnsignedInt();
      final savedPosition = data.currentPosition;

      if (defaultOffset != 0) {
        data.seek(subtableStart + defaultOffset);
        final rangeCount = data.readUnsignedInt();
        final ranges = List<_VariationRange>.empty(growable: true);
        for (var rangeIndex = 0; rangeIndex < rangeCount; rangeIndex++) {
          final startUnicode = _readUInt24(data);
          final additionalCount = data.readUnsignedByte();
          ranges.add(
            _VariationRange(
              startUnicode,
              startUnicode + additionalCount,
            ),
          );
        }
        if (ranges.isNotEmpty) {
          _variationDefaultRanges[variationSelector] = ranges;
        }
      }

      if (nonDefaultOffset != 0) {
        data.seek(subtableStart + nonDefaultOffset);
        final mappingCount = data.readUnsignedInt();
        if (mappingCount > 0) {
          final mappings = <int, int>{};
          for (var mapIndex = 0; mapIndex < mappingCount; mapIndex++) {
            final unicodeValue = _readUInt24(data);
            final glyphId = data.readUnsignedShort();
            mappings[unicodeValue] = glyphId;
          }
          if (mappings.isNotEmpty) {
            _variationGlyphMappings[variationSelector] = mappings;
          }
        }
      }

      data.seek(savedPosition);
    }

    data.seek(subtableStart + _length);
  }

  Set<int> get variationSelectors {
    final selectors = <int>{};
    selectors.addAll(_variationDefaultRanges.keys);
    selectors.addAll(_variationGlyphMappings.keys);
    return Set<int>.unmodifiable(selectors);
  }

  int? getVariationGlyphId(int codePoint, int variationSelector) {
    return _variationGlyphMappings[variationSelector]?[codePoint];
  }

  bool isDefaultVariation(int codePoint, int variationSelector) {
    final ranges = _variationDefaultRanges[variationSelector];
    if (ranges == null) {
      return false;
    }
    for (final range in ranges) {
      if (range.contains(codePoint)) {
        return true;
      }
    }
    return false;
  }

  CmapVariationSelectorData? getVariationSelectorData(int variationSelector) {
    final ranges = _variationDefaultRanges[variationSelector];
    final mappings = _variationGlyphMappings[variationSelector];
    if (ranges == null && mappings == null) {
      return null;
    }
    final publicRanges = ranges == null
        ? const <CmapVariationDefaultRange>[]
        : List<CmapVariationDefaultRange>.unmodifiable(ranges.map((range) =>
            CmapVariationDefaultRange(start: range.start, end: range.end)));
    final publicMappings = mappings == null
        ? const <int, int>{}
        : Map<int, int>.unmodifiable(mappings);
    return CmapVariationSelectorData(publicRanges, publicMappings);
  }

  void _processFormat8(TtfDataStream data, int numGlyphs) {
    _resetMappings();
    final is32 = data.readUnsignedByteArray(8192);
    final groupCount = data.readUnsignedInt();
    if (groupCount > 65536) {
      throw IOException(
        'cmap format 8 possui número de grupos inválido: $groupCount',
      );
    }

    var maxGlyphId = 0;
    for (var groupIndex = 0; groupIndex < groupCount; groupIndex++) {
      final firstCode = data.readUnsignedInt();
      final endCode = data.readUnsignedInt();
      final startGlyph = data.readUnsignedInt();

      if (firstCode > endCode) {
        throw IOException(
          'Intervalo inválido no cmap format 8: firstCode $firstCode, endCode $endCode',
        );
      }

      for (var code = firstCode; code <= endCode; code++) {
        final is32Index = code ~/ 8;
        if (is32Index >= is32.length) {
          throw IOException(
            '[Format 8] codepoint fora da faixa suportada: $code',
          );
        }

        final glyphId = startGlyph + (code - firstCode);
        if (glyphId >= numGlyphs) {
          continue;
        }

        final bitMask = 1 << (code % 8);
        final markedAs32 = (is32[is32Index] & bitMask) != 0;
        int mappedCodePoint;
        if (!markedAs32) {
          mappedCodePoint = code;
        } else {
          final lead = _leadOffset + (code >> 10);
          final trail = 0xDC00 + (code & 0x3FF);
          final scalar = (lead << 10) + trail + _surrogateOffset;
          if (scalar < 0 || scalar > 0x10FFFF) {
            throw IOException(
              '[Format 8] codepoint inválido após reconstrução: $scalar',
            );
          }
          mappedCodePoint = scalar;
        }

        _characterCodeToGlyphId[mappedCodePoint] = glyphId;
        maxGlyphId = max(maxGlyphId, glyphId);
      }
    }

    if (_characterCodeToGlyphId.isNotEmpty) {
      _buildGlyphIdToCharacterCodeLookup(maxGlyphId);
    }
  }

  void _processFormat10(TtfDataStream data, int numGlyphs) {
    _resetMappings();
    final startCode = data.readUnsignedInt();
    final numChars = data.readUnsignedInt();

    if (numChars > 0x7FFFFFFF) {
      throw IOException('Quantidade de caracteres inválida em cmap format 10');
    }

    final endCode = startCode + numChars;
    if (startCode < 0 || startCode > 0x0010FFFF || endCode > 0x0010FFFF) {
      throw IOException(
        'Intervalo inválido no cmap format 10: startCode=$startCode, numChars=$numChars',
      );
    }
    if (endCode >= 0x0000D800 && endCode <= 0x0000DFFF) {
      throw IOException(
        'Intervalo do cmap format 10 entra na zona de surrogates: startCode=$startCode, numChars=$numChars',
      );
    }

    final numCharsInt = numChars.toInt();
    final glyphArray = data.readUnsignedShortArray(numCharsInt);
    var maxGlyphId = 0;

    for (var i = 0; i < numCharsInt; i++) {
      final glyphId = glyphArray[i];
      if (glyphId >= numGlyphs) {
        continue;
      }
      final charCode = startCode + i;
      _characterCodeToGlyphId[charCode] = glyphId;
      maxGlyphId = max(maxGlyphId, glyphId);
    }

    if (_characterCodeToGlyphId.isNotEmpty) {
      _buildGlyphIdToCharacterCodeLookup(maxGlyphId);
    }
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

  void _processFormat13(TtfDataStream data, int numGlyphs) {
    _resetMappings();
    final groupCount = data.readUnsignedInt();
    if (groupCount > 0x7FFFFFFF) {
      throw IOException('Quantidade de grupos inválida no cmap format 13');
    }

    var maxGlyphId = 0;
    for (var group = 0; group < groupCount; group++) {
      final firstCode = data.readUnsignedInt();
      final endCode = data.readUnsignedInt();
      final glyphId = data.readUnsignedInt();

      if (glyphId >= numGlyphs) {
        continue;
      }
      if (firstCode > endCode) {
        throw IOException(
          'Intervalo inválido no cmap format 13: firstCode $firstCode, endCode $endCode',
        );
      }
      if (firstCode < 0 || firstCode > 0x0010FFFF) {
        throw IOException(
            'Character code inválido no cmap format 13: $firstCode');
      }
      if (endCode > 0x0010FFFF) {
        throw IOException(
            'Character code inválido no cmap format 13: $endCode');
      }
      if ((firstCode >= 0xD800 && firstCode <= 0xDFFF) ||
          (endCode >= 0xD800 && endCode <= 0xDFFF)) {
        throw IOException(
            'Intervalo do cmap format 13 cai dentro dos surrogates');
      }

      for (var code = firstCode; code <= endCode; code++) {
        if (code > 0x10FFFF) {
          break;
        }
        _characterCodeToGlyphId[code] = glyphId;
      }
      maxGlyphId = max(maxGlyphId, glyphId.toInt());
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
        final list =
            _glyphIdToCharacterCodeMultiple.putIfAbsent(glyphId, () => <int>[]);
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
    _variationDefaultRanges.clear();
    _variationGlyphMappings.clear();
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

  int _readUInt24(TtfDataStream data) {
    final b1 = data.readUnsignedByte();
    final b2 = data.readUnsignedByte();
    final b3 = data.readUnsignedByte();
    return (b1 << 16) | (b2 << 8) | b3;
  }
}

class _Format2SubHeader {
  const _Format2SubHeader({
    required this.firstCode,
    required this.entryCount,
    required this.idDelta,
    required this.idRangeOffset,
  });

  final int firstCode;
  final int entryCount;
  final int idDelta;
  final int idRangeOffset;
}

class _VariationRange {
  const _VariationRange(this.start, this.end);

  final int start;
  final int end;

  bool contains(int value) => value >= start && value <= end;
}

class CmapVariationSelectorData {
  const CmapVariationSelectorData(
    this.defaultRanges,
    this.nonDefaultMappings,
  );

  final List<CmapVariationDefaultRange> defaultRanges;
  final Map<int, int> nonDefaultMappings;
}

class CmapVariationDefaultRange {
  const CmapVariationDefaultRange({
    required this.start,
    required this.end,
  });

  final int start;
  final int end;

  bool contains(int codePoint) => codePoint >= start && codePoint <= end;
}
