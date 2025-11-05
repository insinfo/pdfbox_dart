import 'package:pdfbox_dart/src/fontbox/encoding/built_in_encoding.dart';
import 'package:pdfbox_dart/src/fontbox/encoding/mac_roman_encoding.dart';
import 'package:pdfbox_dart/src/fontbox/encoding/standard_encoding.dart';
import 'package:test/test.dart';

void main() {
  group('StandardEncoding', () {
    test('basic glyph lookups', () {
      final encoding = StandardEncoding.instance;
      expect(encoding.getName(0x41), 'A');
      expect(encoding.getName(0x61), 'a');
      expect(encoding.getCode('question'), 0x3f);
      expect(encoding.getName(0xff), '.notdef');
    });

    test('codeToNameMap is read-only', () {
      final encoding = StandardEncoding.instance;
      expect(() => encoding.codeToNameMap[0x41] = 'AltA', throwsUnsupportedError);
    });
  });

  group('MacRomanEncoding', () {
    test('special glyph mapping', () {
      final encoding = MacRomanEncoding.instance;
      expect(encoding.getCode('Otilde'), int.parse('0315', radix: 8));
      expect(encoding.getName(int.parse('0245', radix: 8)), 'bullet');
    });
  });

  group('BuiltInEncoding', () {
    test('uses supplied map', () {
      final encoding = BuiltInEncoding({65: 'Athing', 66: 'Bthing'});
      expect(encoding.getName(65), 'Athing');
      expect(encoding.getCode('Bthing'), 66);
    });
  });
}
