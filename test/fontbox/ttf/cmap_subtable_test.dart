import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/cmap_subtable.dart';
import 'package:test/test.dart';

void main() {
  group('CmapSubtable', () {
    test('mapeia codepoints para glyph IDs', () {
      final cmap = CmapSubtable()
        ..addMapping(0x0041, 3)
        ..addMapping(0x0061, 5)
        ..addMapping(0x24B6, 3);

      expect(cmap.getGlyphId(0x0041), 3);
      expect(cmap.getGlyphId(0x0042), 0);
      expect(cmap.getGlyphId(0x24B6), 3);

      final glyph3Codes = cmap.getCharCodes(3);
      expect(glyph3Codes, orderedEquals(<int>[0x0041, 0x24B6]));

      final glyph5Codes = cmap.getCharCodes(5);
      expect(glyph5Codes, orderedEquals(<int>[0x0061]));
    });

    test('removeMapping elimina associações vazias', () {
      final cmap = CmapSubtable()
        ..addMapping(0x0041, 3)
        ..addMapping(0x24B6, 3);

      cmap.removeMapping(0x0041);
      expect(cmap.getGlyphId(0x0041), 0);
      expect(cmap.getCharCodes(3), orderedEquals(<int>[0x24B6]));

      cmap.removeMapping(0x24B6);
      expect(cmap.getGlyphId(0x24B6), 0);
      expect(cmap.getCharCodes(3), isNull);
      expect(cmap.mappingCount, 0);
    });

    test('copyFrom duplica mapeamentos existentes', () {
      final source = CmapSubtable()
        ..addMapping(0x0041, 3)
        ..addMapping(0x00C7, 7);

      final copy = CmapSubtable();
      copy.copyFrom(source);

      expect(copy.getGlyphId(0x0041), 3);
      expect(copy.getGlyphId(0x00C7), 7);
      expect(copy.getCharCodes(7), orderedEquals(<int>[0x00C7]));
      expect(copy.mappingCount, 2);
    });

    test('initSubtable interpreta formato 4 com idDelta', () {
      final data = _streamForSubtable(_format4Subtable());
      final cmap = CmapSubtable()
        ..initData(data)
        ..initSubtable(0, 16, data);

      expect(cmap.getGlyphId(0x0041), 3);
      expect(cmap.getGlyphId(0x0042), 0);
      expect(cmap.getCharCodes(3), orderedEquals(<int>[0x0041]));
    });

    test('initSubtable interpreta formato 2 com subheaders múltiplos', () {
      final data = _streamForSubtable(_format2Subtable());
      final cmap = CmapSubtable()
        ..initData(data)
        ..initSubtable(0, 32, data);

      expect(cmap.getGlyphId(0x0020), 3);
      expect(cmap.getGlyphId(0x0021), 5);
      expect(cmap.getGlyphId(0x0102), 9);
      expect(cmap.getCharCodes(5), orderedEquals(<int>[0x0021]));
      expect(cmap.getCharCodes(9), orderedEquals(<int>[0x0102]));
    });

    test('initSubtable interpreta formato 8 com mapeamento misto', () {
      final data = _streamForSubtable(_format8Subtable());
      final cmap = CmapSubtable()
        ..initData(data)
        ..initSubtable(0, 64, data);

      expect(cmap.getGlyphId(0x0041), 3);
      expect(cmap.getGlyphId(0x0042), 4);
      expect(cmap.getGlyphId(0xD800), 30);
      expect(cmap.getCharCodes(3), orderedEquals(<int>[0x0041]));
      expect(cmap.getCharCodes(30), orderedEquals(<int>[0xD800]));
    });

    test('initSubtable interpreta formato 10 com caracteres acima do BMP', () {
      final data = _streamForSubtable(_format10Subtable());
      final cmap = CmapSubtable()
        ..initData(data)
        ..initSubtable(0, 1024, data);

      expect(cmap.getGlyphId(0x1F600), 400);
      expect(cmap.getGlyphId(0x1F601), 401);
      expect(cmap.getCharCodes(400), orderedEquals(<int>[0x1F600]));
    });

    test('initSubtable interpreta formato 13 com ranges para mesmo glyph', () {
      final data = _streamForSubtable(_format13Subtable());
      final cmap = CmapSubtable()
        ..initData(data)
        ..initSubtable(0, 64, data);

      expect(cmap.getGlyphId(0x0100), 7);
      expect(cmap.getGlyphId(0x0101), 7);
      expect(cmap.getCharCodes(7), orderedEquals(<int>[0x0100, 0x0101]));
    });

    test('initSubtable interpreta formato 14 com sequências de variação', () {
      final data = _streamForSubtable(_format14Subtable());
      final cmap = CmapSubtable()
        ..initData(data)
        ..initSubtable(0, 64, data);

      expect(cmap.mappingCount, 0);
      expect(cmap.variationSelectors, contains(0xFE0F));
      expect(cmap.isDefaultVariation(0x1F600, 0xFE0F), isTrue);
      expect(cmap.isDefaultVariation(0x1F601, 0xFE0F), isFalse);
      expect(cmap.getVariationGlyphId(0x1F601, 0xFE0F), 520);

      final selectorData = cmap.getVariationSelectorData(0xFE0F);
      expect(selectorData, isNotNull);
      expect(selectorData!.defaultRanges.length, 1);
      expect(selectorData.nonDefaultMappings.length, 1);
      expect(selectorData.nonDefaultMappings[0x1F601], 520);
    });

    test('mergeVariationData combina UVS não padrão ao cmap base', () {
      final base = _parseCmap(_format12Subtable(), numGlyphs: 1024);
      final variation = _parseCmap(_format14Subtable(), numGlyphs: 1024);

      base.mergeVariationData(variation);

      expect(base.getGlyphId(0x1F600), 400);
      expect(base.getGlyphId(0x1F601), 401);
      expect(base.getGlyphId(0x1F601, 0xFE0F), 520);
      expect(base.isDefaultVariation(0x1F600, 0xFE0F), isTrue);
    });

    test('mapCodePoints consome seletores de variação associados', () {
      final base = _parseCmap(_format12Subtable(), numGlyphs: 1024);
      final variation = _parseCmap(_format14Subtable(), numGlyphs: 1024);
      base.mergeVariationData(variation);

      final glyphs =
          base.mapCodePoints(<int>[0x1F600, 0xFE0F, 0x1F601, 0xFE0F, 0x1F601]);
      expect(glyphs, orderedEquals(<int>[400, 520, 401]));
    });

    test('initSubtable interpreta formato 6 sequencial', () {
      final data = _streamForSubtable(_format6Subtable());
      final cmap = CmapSubtable()
        ..initData(data)
        ..initSubtable(0, 16, data);

      expect(cmap.getGlyphId(0x0020), 1);
      expect(cmap.getGlyphId(0x0021), 2);
      expect(cmap.getGlyphId(0x0022), 7);
      expect(cmap.getCharCodes(2), orderedEquals(<int>[0x0021]));
    });

    test('initSubtable interpreta formato 12 com caracteres acima de BMP', () {
      final data = _streamForSubtable(_format12Subtable());
      final cmap = CmapSubtable()
        ..initData(data)
        ..initSubtable(0, 1024, data);

      expect(cmap.getGlyphId(0x1F600), 400);
      expect(cmap.getGlyphId(0x1F601), 401);
      expect(cmap.getCharCodes(401), orderedEquals(<int>[0x1F601]));
    });
  });
}

RandomAccessReadDataStream _streamForSubtable(List<int> subtableBytes) {
  final builder = BytesBuilder();
  builder
    ..add(_u16(3))
    ..add(_u16(1))
    ..add(_u32(8))
    ..add(subtableBytes);
  return RandomAccessReadDataStream.fromData(builder.toBytes());
}

List<int> _format4Subtable() {
  final data = <int>[];
  data
    ..addAll(_u16(4))
    ..addAll(_u16(0x0020))
    ..addAll(_u16(0))
    ..addAll(_u16(0x0004))
    ..addAll(_u16(0x0004))
    ..addAll(_u16(0x0001))
    ..addAll(_u16(0x0000))
    ..addAll(_u16(0x0041))
    ..addAll(_u16(0xFFFF))
    ..addAll(_u16(0x0000))
    ..addAll(_u16(0x0041))
    ..addAll(_u16(0xFFFF))
    ..addAll(_u16(0xFFC2))
    ..addAll(_u16(0x0001))
    ..addAll(_u16(0x0000))
    ..addAll(_u16(0x0000));
  return data;
}

List<int> _format2Subtable() {
  final data = <int>[];
  data
    ..addAll(_u16(2))
    ..addAll(_u16(0x021C))
    ..addAll(_u16(0));

  final keys = List<int>.filled(256, 0);
  keys[1] = 8;
  for (final key in keys) {
    data.addAll(_u16(key));
  }

  data
    ..addAll(_u16(0x0020))
    ..addAll(_u16(2))
    ..addAll(_u16(0))
    ..addAll(_u16(0x000A))
    ..addAll(_u16(0x0002))
    ..addAll(_u16(1))
    ..addAll(_u16(0))
    ..addAll(_u16(0x0006))
    ..addAll(_u16(3))
    ..addAll(_u16(5))
    ..addAll(_u16(9));

  return data;
}

List<int> _format8Subtable() {
  final data = <int>[];
  const groupCount = 2;
  const length = 12 + 8192 + 4 + (groupCount * 12);

  final is32 = List<int>.filled(8192, 0);
  final surrogateIndex = 0xD800;
  is32[surrogateIndex ~/ 8] |= 1 << (surrogateIndex % 8);

  data
    ..addAll(_u16(8))
    ..addAll(_u16(0))
    ..addAll(_u32(length))
    ..addAll(_u32(0))
    ..addAll(is32)
    ..addAll(_u32(groupCount))
    ..addAll(_u32(0x00000041))
    ..addAll(_u32(0x00000042))
    ..addAll(_u32(3))
    ..addAll(_u32(0x0000D800))
    ..addAll(_u32(0x0000D800))
    ..addAll(_u32(30));

  return data;
}

List<int> _format10Subtable() {
  final data = <int>[];
  const numChars = 2;
  const length = 2 + 2 + 4 + 4 + 4 + 4 + (numChars * 2);

  data
    ..addAll(_u16(10))
    ..addAll(_u16(0))
    ..addAll(_u32(length))
    ..addAll(_u32(0))
    ..addAll(_u32(0x001F600))
    ..addAll(_u32(numChars))
    ..addAll(_u16(400))
    ..addAll(_u16(401));

  return data;
}

List<int> _format13Subtable() {
  final data = <int>[];
  const groupCount = 1;
  const length = 2 + 2 + 4 + 4 + 4 + (groupCount * 12);

  data
    ..addAll(_u16(13))
    ..addAll(_u16(0))
    ..addAll(_u32(length))
    ..addAll(_u32(0))
    ..addAll(_u32(groupCount))
    ..addAll(_u32(0x00000100))
    ..addAll(_u32(0x00000101))
    ..addAll(_u32(7));

  return data;
}

List<int> _format14Subtable() {
  final data = <int>[];

  data
    ..addAll(_u16(14))
    ..addAll(_u16(0))
    ..addAll(_u32(0)) // placeholder length
    ..addAll(_u32(1)); // variation selector count

  data.addAll(_u24(0x00FE0F));
  final defaultOffsetIndex = data.length;
  data.addAll(_u32(0));
  final nonDefaultOffsetIndex = data.length;
  data.addAll(_u32(0));

  data.add(0); // pad to align offsets to 4 bytes

  final defaultOffset = data.length;
  data
    ..addAll(_u32(1))
    ..addAll(_u24(0x001F600))
    ..add(0);

  while (data.length % 4 != 0) {
    data.add(0);
  }

  final nonDefaultOffset = data.length;
  data
    ..addAll(_u32(1))
    ..addAll(_u24(0x001F601))
    ..addAll(_u16(520));

  final length = data.length;
  _writeU32(data, 4, length);
  _writeU32(data, defaultOffsetIndex, defaultOffset);
  _writeU32(data, nonDefaultOffsetIndex, nonDefaultOffset);

  return data;
}

List<int> _format6Subtable() {
  final data = <int>[];
  data
    ..addAll(_u16(6))
    ..addAll(_u16(0x0010))
    ..addAll(_u16(0))
    ..addAll(_u16(0x0020))
    ..addAll(_u16(3))
    ..addAll(_u16(1))
    ..addAll(_u16(2))
    ..addAll(_u16(7));
  return data;
}

List<int> _format12Subtable() {
  final data = <int>[];
  data
    ..addAll(_u16(12))
    ..addAll(_u16(0))
    ..addAll(_u32(0x0000001C))
    ..addAll(_u32(0))
    ..addAll(_u32(1))
    ..addAll(_u32(0x1F600))
    ..addAll(_u32(0x1F601))
    ..addAll(_u32(400));
  return data;
}

List<int> _u16(int value) => <int>[(value >> 8) & 0xFF, value & 0xFF];

List<int> _u32(int value) => <int>[
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

List<int> _u24(int value) => <int>[
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

CmapSubtable _parseCmap(List<int> subtableBytes, {int numGlyphs = 64}) {
  final data = _streamForSubtable(subtableBytes);
  return CmapSubtable()
    ..initData(data)
    ..initSubtable(0, numGlyphs, data);
}

void _writeU32(List<int> buffer, int offset, int value) {
  buffer[offset] = (value >> 24) & 0xFF;
  buffer[offset + 1] = (value >> 16) & 0xFF;
  buffer[offset + 2] = (value >> 8) & 0xFF;
  buffer[offset + 3] = value & 0xFF;
}
