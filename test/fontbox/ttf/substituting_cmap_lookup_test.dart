import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/cmap_subtable.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyph_substitution_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/substituting_cmap_lookup.dart';
import 'package:test/test.dart';

void main() {
  group('SubstitutingCmapLookup', () {
    late CmapSubtable cmap;

    setUp(() {
      cmap = _parseCmap(_format12Subtable(), numGlyphs: 1024);
      final variation = _parseCmap(_format14Subtable(), numGlyphs: 1024);
      cmap.mergeVariationData(variation);
    });

    test('getGlyphId aplica UVS antes das substituições GSUB', () {
      final lookup = SubstitutingCmapLookup(
          cmap, GlyphSubstitutionTable(), const <String>[]);
      expect(lookup.getGlyphId(0x1F601, 0xFE0F), 520);
      expect(lookup.getGlyphId(0x1F600, 0xFE0F), 400);
    });

    test('mapCodePoints ignora seletores isolados e combina UVS', () {
      final lookup = SubstitutingCmapLookup(
          cmap, GlyphSubstitutionTable(), const <String>[]);
      final glyphs = lookup.mapCodePoints(
          <int>[0xFE0F, 0x1F600, 0xFE0F, 0x1F601, 0xFE0F, 0x1F601]);
      expect(glyphs, orderedEquals(<int>[400, 520, 401]));
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

List<int> _format14Subtable() {
  final data = <int>[];
  data
    ..addAll(_u16(14))
    ..addAll(_u16(0))
    ..addAll(_u32(0))
    ..addAll(_u32(1));

  data.addAll(_u24(0x00FE0F));
  final defaultOffsetIndex = data.length;
  data.addAll(_u32(0));
  final nonDefaultOffsetIndex = data.length;
  data.addAll(_u32(0));

  data.add(0);

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

CmapSubtable _parseCmap(List<int> subtableBytes, {int numGlyphs = 64}) {
  final data = _streamForSubtable(subtableBytes);
  return CmapSubtable()
    ..initData(data)
    ..initSubtable(0, numGlyphs, data);
}

List<int> _u16(int value) => <int>[(value >> 8) & 0xFF, value & 0xFF];

List<int> _u24(int value) => <int>[
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

List<int> _u32(int value) => <int>[
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

void _writeU32(List<int> buffer, int offset, int value) {
  buffer[offset] = (value >> 24) & 0xFF;
  buffer[offset + 1] = (value >> 16) & 0xFF;
  buffer[offset + 2] = (value >> 8) & 0xFF;
  buffer[offset + 3] = value & 0xFF;
}
