import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_type1_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/standard14_fonts.dart';
import 'package:test/test.dart';

void main() {
  group('PDType1Font.standard14', () {
    test('creates font dictionary with expected entries', () {
      final helvetica = Standard14Fonts.byPostScriptName('Helvetica');
      expect(helvetica, isNotNull);
      final font = PDType1Font.standard14(helvetica!);
      final dictionary = font.cosObject;

      expect(dictionary.getNameAsString(COSName.type), 'Font');
      expect(dictionary.getNameAsString(COSName.subtype), 'Type1');
      expect(dictionary.getNameAsString(COSName.baseFont), 'Helvetica');
      expect(dictionary.getNameAsString(COSName.encoding), 'WinAnsiEncoding');
    });

    test('widths and unicode mapping use AFM metrics', () {
      final helvetica = Standard14Fonts.byPostScriptName('Helvetica');
      expect(helvetica, isNotNull);
      final font = PDType1Font.standard14(helvetica!);
      expect(font.getWidthFromFont(65), closeTo(667, 1e-6));
      expect(font.toUnicode(65), 'A');
      expect(font.getStringWidth('ABC'), closeTo(667 + 667 + 722, 1e-6));
    });

    test('Symbol font uses built-in encoding without dictionary entry', () {
      final symbol = Standard14Fonts.byPostScriptName('Symbol');
      expect(symbol, isNotNull);
      final font = PDType1Font.standard14(symbol!);
      final dictionary = font.cosObject;

      expect(dictionary.getNameAsString(COSName.baseFont), 'Symbol');
      expect(dictionary.getDictionaryObject(COSName.encoding), isNull);
      expect(font.toUnicode(65), equals('Α'));
    });

    test('common aliases resolve to standard 14 fonts', () {
      final arial = Standard14Fonts.byPostScriptName('ArialMT');
      final helvetica = Standard14Fonts.byPostScriptName('Helvetica');
      expect(arial, same(helvetica));

      final timesAlias = Standard14Fonts.byPostScriptName('TimesNewRomanPSMT');
      final times = Standard14Fonts.byPostScriptName('Times-Roman');
      expect(timesAlias, same(times));
    });
  });
}
