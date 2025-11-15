import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/sasl_prep.dart';
import 'package:test/test.dart';

void main() {
  group('SaslPrep', () {
    test('maps non ASCII spaces to ASCII space', () {
      final input = 'user\u00A0name';
      expect(SaslPrep.saslPrepStored(input), 'user name');
    });

    test('removes commonly mapped to nothing characters', () {
      final input = 'I\u00ADX';
      expect(SaslPrep.saslPrepStored(input), 'IX');
    });

    test('normalizes to NFKC', () {
      // U+212B ANGSTROM SIGN normalizes to U+00C5 LATIN CAPITAL LETTER A WITH RING ABOVE.
      const input = '\u212B';
      expect(SaslPrep.saslPrepStored(input), '\u00C5');
    });

    test('rejects prohibited control characters', () {
      const input = 'bad\u0007pass';
      expect(() => SaslPrep.saslPrepStored(input), throwsArgumentError);
    });

    test('rejects mixed RandALCat and LCat content', () {
      const input = 'A\u05D0';
      expect(() => SaslPrep.saslPrepStored(input), throwsArgumentError);
    });

    test('forces RandALCat string to end with RandALCat', () {
      const input = '\u05D0A';
      expect(() => SaslPrep.saslPrepStored(input), throwsArgumentError);
    });

    test('accepts purely RandALCat input', () {
      const input = '\u05D0\u05D1';
      expect(SaslPrep.saslPrepStored(input), input);
    });
  });
}
