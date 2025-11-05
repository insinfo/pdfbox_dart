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
  });
}
