import 'package:pdfbox_dart/src/fontbox/util/glyph_list.dart';
import 'package:test/test.dart';

void main() {
  group('GlyphList', () {
    test('adobe glyph unicode lookup', () {
      final list = GlyphList.adobeGlyphList;
      expect(list.unicodeForName('Aacute'), '\u00C1');
      expect(list.nameForCodePoint(0x00C5), 'Aring');
    });

    test('code points view is read-only', () {
      final list = GlyphList.adobeGlyphList;
      final codePoints = list.codePointsForName('A');
      expect(codePoints, [0x41]);
      expect(() => codePoints![0] = 0x61, throwsUnsupportedError);
    });

    test('zapf dingbats overlay', () {
      final list = GlyphList.zapfDingbatsGlyphList;
      final heart = list.codePointsForName('a104');
      expect(heart, isNotNull);
      expect(heart, [0x2764]);
      expect(list.nameForString(String.fromCharCode(0x2764)), 'a104');
    });
  });
}
