import 'dart:convert';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/to_unicode_writer.dart';

void main() {
  group('ToUnicodeWriter', () {
    test('allowCidToUnicodeRange merges sequential entries', () {
      const previous = MapEntry<int, String>(0x1234, 'A');
      const next = MapEntry<int, String>(0x1235, 'B');

      expect(ToUnicodeWriter.allowCidToUnicodeRange(previous, next), isTrue);
    });

    test('toBytes emits ascii ToUnicode CMap', () {
      final writer = ToUnicodeWriter();
      writer.add(0x0001, 'A');
      writer.add(0x0002, 'B');
      writer.add(0x0004, 'D');

      final cmap = ascii.decode(writer.toBytes());

      expect(cmap, contains('begincmap'));
      expect(cmap, contains('2 beginbfrange'));
      expect(cmap, contains('<0001> <0002> <0041>'));
      expect(cmap, contains('<0004> <0004> <0044>'));
      expect(cmap.trim().endsWith('end'), isTrue);
    });
  });
}
