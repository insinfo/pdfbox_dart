import 'package:pdfbox_dart/src/fontbox/ttf/wgl4_names.dart';
import 'package:test/test.dart';

void main() {
  group('Wgl4Names', () {
    test('resolves glyph indices and names', () {
      expect(Wgl4Names.getGlyphIndex('A'), 36);
      expect(Wgl4Names.getGlyphIndex('non-existent'), isNull);

      expect(Wgl4Names.getGlyphName(36), 'A');
      expect(Wgl4Names.getGlyphName(-1), isNull);
      expect(Wgl4Names.getGlyphName(1000), isNull);
    });

    test('provides snapshot of all names', () {
      final names = Wgl4Names.getAllNames();
      expect(names, hasLength(Wgl4Names.numberOfMacGlyphs));
      expect(names.first, '.notdef');
      expect(names.last, 'dcroat');
    });
  });
}
