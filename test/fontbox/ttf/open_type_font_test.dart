import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/cff_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/open_type_font.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/ttf_table.dart';
import 'package:test/test.dart';

void main() {
  group('OpenTypeFont', () {
    test('reports PostScript outlines and exposes CFF table', () {
      final font = _buildFont();
      addTearDown(font.close);

      final cff = CffTable()
        ..setTag(CffTable.tableTag)
        ..setOffset(0)
        ..setLength(4)
        ..setInitialized(true);
      font.addTable(cff);
      font.setVersion(2000);

      expect(font.isPostScript, isTrue);
      expect(font.isSupportedOtf, isTrue);
      expect(font.getCffTable(), same(cff));
    });

    test('throws when CFF table is requested on TTF font', () {
      final font = _buildFont();
      addTearDown(font.close);

      expect(font.isPostScript, isFalse);
      expect(() => font.getCffTable(), throwsA(isA<UnsupportedError>()));
    });

    test('detects advanced layout tables', () {
      final font = _buildFont();
      addTearDown(font.close);

      expect(font.hasLayoutTables, isFalse);

      final gpos = TtfTable()
        ..setTag('GPOS')
        ..setOffset(0)
        ..setLength(0)
        ..setInitialized(true);
      font.addTable(gpos);

      expect(font.hasLayoutTables, isTrue);
    });

    test('treats glyph table as unavailable for PostScript OTF fonts', () {
      final font = _buildFont();
      addTearDown(font.close);

      final cff = CffTable()
        ..setTag(CffTable.tableTag)
        ..setOffset(0)
        ..setLength(0)
        ..setInitialized(true);
      font.addTable(cff);
      font.setVersion(2048);

      expect(() => font.getGlyphTable(), throwsA(isA<UnsupportedError>()));
    });
  });
}

OpenTypeFont _buildFont() {
  final data = RandomAccessReadDataStream.fromData(Uint8List(0));
  return OpenTypeFont(data);
}
