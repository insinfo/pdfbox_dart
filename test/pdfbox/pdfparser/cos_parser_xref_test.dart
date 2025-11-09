import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/cos_parser.dart';
import 'package:test/test.dart';

COSParser _parserFrom(String content) {
  final bytes = Uint8List.fromList(content.codeUnits);
  return COSParser(RandomAccessReadBuffer.fromBytes(bytes));
}

void main() {
  group('COSParser xref/trailer parsing', () {
    test('parses single-section xref tables', () {
      final parser = _parserFrom('xref\n0 3\n0000000000 65535 f \n0000000010 00000 n \n0000000123 00001 n \ntrailer\n<< /Size 3 /Root 1 0 R >>\nstartxref\n456\n%%EOF');

      final result = parser.parseXrefTrailer();
      expect(result.entries.length, 3);
      expect(result.entries[0]!.inUse, isFalse);
      expect(result.entries[1]!.offset, 10);
      expect(result.entries[2]!.generation, 1);
      expect(result.startXref, 456);

  expect(result.trailer.containsKey(COSName.get('Root')), isTrue);
  expect(result.trailer.getInt(COSName.get('Size')), 3);
    });

    test('handles multiple xref sections', () {
      final parser = _parserFrom('xref\n0 1\n0000000000 65535 f \n2 2\n0000000200 00000 n \n0000000300 00005 n \ntrailer\n<< /Size 4 /Prev 32 >>\nstartxref\n512\n%%EOF');

      final result = parser.parseXrefTrailer();
      expect(result.entries.length, 3);
      expect(result.entries[2]!.offset, 200);
  expect(result.entries[3]!.generation, 5);
  expect(result.trailer.getInt(COSName.get('Size')), 4);
  expect(result.trailer.getInt(COSName.get('Prev')), 32);
    });
  });
}
