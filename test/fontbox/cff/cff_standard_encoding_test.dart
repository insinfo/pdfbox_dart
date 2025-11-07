import 'package:pdfbox_dart/src/fontbox/cff/cff_standard_encoding.dart';
import 'package:pdfbox_dart/src/fontbox/cff/cff_standard_string.dart';
import 'package:test/test.dart';

void main() {
  group('CFFStandardString', () {
    test('returns mapped names', () {
      expect(CFFStandardString.getName(0), '.notdef');
      expect(CFFStandardString.getName(34), 'A');
    });

    test('throws for out of range sid', () {
      expect(() => CFFStandardString.getName(-1), throwsRangeError);
      expect(() => CFFStandardString.getName(1000), throwsRangeError);
    });
  });

  group('CFFStandardEncoding', () {
    test('singleton instance reuses mapping', () {
      final encodingA = CFFStandardEncoding.getInstance();
      final encodingB = CFFStandardEncoding.getInstance();
      expect(identical(encodingA, encodingB), isTrue);
    });

    test('provides glyph name for code', () {
      final encoding = CFFStandardEncoding.getInstance();
      expect(encoding.getName(65), 'A');
      expect(encoding.getName(0), '.notdef');
      expect(encoding.getName(245), 'dotlessi');
    });

    test('provides code for glyph name', () {
      final encoding = CFFStandardEncoding.getInstance();
      expect(encoding.getCode('A'), 65);
      expect(encoding.getCode('dotlessi'), 245);
    });
  });
}
