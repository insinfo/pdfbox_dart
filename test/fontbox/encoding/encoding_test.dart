import 'package:pdfbox_dart/src/fontbox/encoding/built_in_encoding.dart';
import 'package:pdfbox_dart/src/fontbox/encoding/mac_expert_encoding.dart';
import 'package:pdfbox_dart/src/fontbox/encoding/mac_roman_encoding.dart';
import 'package:pdfbox_dart/src/fontbox/encoding/symbol_encoding.dart';
import 'package:pdfbox_dart/src/fontbox/encoding/standard_encoding.dart';
import 'package:pdfbox_dart/src/fontbox/encoding/win_ansi_encoding.dart';
import 'package:pdfbox_dart/src/fontbox/encoding/zapf_dingbats_encoding.dart';
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

  group('MacExpertEncoding', () {
    test('small caps entries', () {
      final encoding = MacExpertEncoding.instance;
      expect(encoding.getCode('AEsmall'), int.parse('0276', radix: 8));
      expect(encoding.getName(int.parse('0215', radix: 8)), 'Ccedillasmall');
    });
  });

  group('WinAnsiEncoding', () {
    test('known WinAnsi mappings', () {
      final encoding = WinAnsiEncoding.instance;
      expect(encoding.getCode('Euro'), 0x80);
      expect(encoding.getName(0xFC), 'udieresis');
    });

    test('fills undefined slots with bullet', () {
      final encoding = WinAnsiEncoding.instance;
      expect(encoding.getName(129), 'bullet');
    });
  });

  group('SymbolEncoding', () {
    test('maps greek glyphs', () {
      final encoding = SymbolEncoding.instance;
      expect(encoding.getName(65), 'Alpha');
      expect(encoding.getCode('omega'), 119);
    });
  });

  group('ZapfDingbatsEncoding', () {
    test('maps dingbat glyphs', () {
      final encoding = ZapfDingbatsEncoding.instance;
      expect(encoding.getName(126), 'a100');
      expect(encoding.getCode('a55'), 92);
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
