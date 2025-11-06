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
