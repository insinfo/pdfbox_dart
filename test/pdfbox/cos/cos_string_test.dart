import 'dart:convert';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:test/test.dart';

void main() {
  group('COSString', () {
    test('encodes and decodes UTF-8 reliably', () {
      const text = 'Olá PDFBox';
      final cosString = COSString(text);

  expect(cosString.string, equals(text));
  expect(cosString.bytes.length, equals(utf8.encode(text).length));
    });

    test('decodes hexadecimal representation', () {
      final cosString = COSString.fromHex('48656C6C6F');
      expect(cosString.string, equals('Hello'));
    });

    test('implements equality by byte content', () {
      final left = COSString('Test');
      final right = COSString('Test');

      expect(left, equals(right));
      expect(left.hashCode, equals(right.hashCode));
    });
  });
}
