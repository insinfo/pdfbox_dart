import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/encoding/glyph_list.dart';
import 'package:test/test.dart';

void main() {
  group('PDFBox GlyphList wrapper', () {
    test('delegates Adobe glyph lookups', () {
      final glyphList = GlyphList.getAdobeGlyphList();
      expect(glyphList.toUnicode('Aacute'), '\u00C1');
      expect(glyphList.codePointToName(0x00C5), 'Aring');
    });

    test('delegates Zapf Dingbats lookups', () {
      final glyphList = GlyphList.getZapfDingbats();
      final heart = String.fromCharCode(0x2764);
      expect(glyphList.sequenceToName(heart), 'a104');
      expect(glyphList.contains('a104'), isTrue);
    });

    test('returns null when glyph unresolved', () {
      final glyphList = GlyphList.getAdobeGlyphList();
      expect(glyphList.toUnicode('NoSuchGlyph'), isNull);
    });
  });
}
