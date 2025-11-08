import 'package:pdfbox_dart/src/fontbox/cff/cff_expert_charset.dart';
import 'package:pdfbox_dart/src/fontbox/cff/cff_expert_subset_charset.dart';
import 'package:pdfbox_dart/src/fontbox/cff/cff_iso_adobe_charset.dart';
import 'package:test/test.dart';

void main() {
  group('CFF ISO Adobe charset', () {
    test('exposes singleton', () {
      final first = CFFISOAdobeCharset.instance;
      final second = CFFISOAdobeCharset.instance;
      expect(identical(first, second), isTrue);
      expect(first.isCIDFont, isFalse);
    });

    test('maps glyphs to SIDs and names', () {
      final charset = CFFISOAdobeCharset.instance;
      expect(charset.getSIDForGID(0), 0);
      expect(charset.getSIDForGID(34), 34);
      expect(charset.getNameForGID(34), 'A');
      expect(charset.getSID('Thorn'), 157);
      expect(charset.getGIDForSID(157), greaterThan(0));
    });
  });

  group('CFF Expert charset', () {
    test('exposes singleton', () {
      final first = CFFExpertCharset.instance;
      final second = CFFExpertCharset.instance;
      expect(identical(first, second), isTrue);
    });

    test('maps expert glyphs', () {
      final charset = CFFExpertCharset.instance;
      expect(charset.getSIDForGID(1), 1);
      expect(charset.getSIDForGID(2), 229);
      expect(charset.getNameForGID(2), 'exclamsmall');
      expect(charset.getSID('ffl'), 268);
      expect(charset.getGIDForSID(268), greaterThan(0));
    });
  });

  group('CFF Expert subset charset', () {
    test('exposes singleton', () {
      final first = CFFExpertSubsetCharset.instance;
      final second = CFFExpertSubsetCharset.instance;
      expect(identical(first, second), isTrue);
    });

    test('maps subset glyphs', () {
      final charset = CFFExpertSubsetCharset.instance;
      expect(charset.getSIDForGID(0), 0);
      expect(charset.getSIDForGID(1), 1);
      expect(charset.getSIDForGID(2), 231);
      expect(charset.getNameForGID(2), 'dollaroldstyle');
      expect(charset.getSID('zerosuperior'), 326);
      expect(charset.getGIDForSID(326), greaterThan(0));
    });
  });
}
