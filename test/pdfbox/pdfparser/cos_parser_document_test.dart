import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/cos_parser.dart';
import 'package:test/test.dart';

COSParser _parserFrom(String content) {
  final bytes = Uint8List.fromList(content.codeUnits);
  return COSParser(RandomAccessReadBuffer.fromBytes(bytes));
}

void main() {
  group('COSParser document loading', () {
    test('loads simple document from xref table', () {
      final buffer = StringBuffer();
      var offset = 0;
      void append(String value) {
        buffer.write(value);
        offset += value.length;
      }

      append('%PDF-1.4\n');
      final obj1Offset = offset;
      append('1 0 obj\n');
      append('<< /Type /Catalog >>\n');
      append('endobj\n');
      final xrefOffset = offset;
      append('xref\n');
      append('0 2\n');
      append('0000000000 65535 f \n');
      append('${obj1Offset.toString().padLeft(10, '0')} 00000 n \n');
      append('trailer\n');
      append('<< /Size 2 /Root 1 0 R >>\n');
      append('startxref\n');
      append('$xrefOffset\n');
      append('%%EOF');

      final parser = _parserFrom(buffer.toString());
      final document = parser.parseDocument();

      expect(document.trailer.getInt(COSName.get('Size')), 2);
      final catalog = document.getObjectByNumber(1)!.object as COSDictionary;
      expect(catalog.getCOSName(COSName.type)!.name, 'Catalog');
    });

    test('loads incremental updates following Prev chain', () {
      final buffer = StringBuffer();
      var offset = 0;
      void append(String value) {
        buffer.write(value);
        offset += value.length;
      }

      append('%PDF-1.4\n');
      final obj1Offset = offset;
      append('1 0 obj\n');
      append('<< /Type /Catalog >>\n');
      append('endobj\n');
      final firstXrefOffset = offset;
      append('xref\n');
      append('0 2\n');
      append('0000000000 65535 f \n');
      append('${obj1Offset.toString().padLeft(10, '0')} 00000 n \n');
      append('trailer\n');
      append('<< /Size 2 /Root 1 0 R >>\n');
      append('startxref\n');
      append('$firstXrefOffset\n');
      append('%%EOF\n');

      final obj2Offset = offset;
      append('2 0 obj\n');
      append('<< /Type /Info >>\n');
      append('endobj\n');
      final secondXrefOffset = offset;
      append('xref\n');
      append('2 1\n');
      append('${obj2Offset.toString().padLeft(10, '0')} 00000 n \n');
      append('trailer\n');
      append('<< /Size 3 /Root 1 0 R /Prev $firstXrefOffset >>\n');
      append('startxref\n');
      append('$secondXrefOffset\n');
      append('%%EOF');

      final parser = _parserFrom(buffer.toString());
      final document = parser.parseDocument();

      expect(document.trailer.getInt(COSName.get('Size')), 3);
      final info = document.getObjectByNumber(2)!.object as COSDictionary;
      expect(info.getCOSName(COSName.type)!.name, 'Info');
      expect(document.getObjectByNumber(1), isNotNull);
    });
  });
}
