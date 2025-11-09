import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_document.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/cos_parser.dart';
import 'package:test/test.dart';

COSParser _parserFrom(String content) {
  final bytes = Uint8List.fromList(content.codeUnits);
  return COSParser(RandomAccessReadBuffer.fromBytes(bytes));
}

void main() {
  group('COSParser indirect objects', () {
    test('parses stream objects and keeps length metadata', () {
      const content = '1 0 obj\n<< /Length 4 /Type /XObject >>\nstream\nData\nendstream\nendobj\n';
      final parser = _parserFrom(content);

      final cosObject = parser.parseIndirectObject()!;
      expect(cosObject.objectNumber, 1);
      expect(cosObject.generationNumber, 0);

      final stream = cosObject.object as COSStream;
      expect(stream.getCOSName(COSName.type)!.name, 'XObject');
      expect(stream.getInt(COSName.length), 4);
      expect(stream.data, equals(Uint8List.fromList('Data'.codeUnits)));
    });

    test('stores parsed objects in a COSDocument when provided', () {
      const content = '2 0 obj\n<< /Type /Catalog >>\nendobj\n';
      final parser = _parserFrom(content);
      final document = COSDocument();

  final cosObject = parser.parseIndirectObject(document: document)!;
  expect(document.getObjectByNumber(2)?.object, same(cosObject.object));

  final dict = cosObject.object as COSDictionary;
  expect(dict.getCOSName(COSName.type)!.name, 'Catalog');
    });

    test('parses objects at specific offsets', () {
      const content = '1 0 obj\n<< /Type /Metadata >>\nendobj\n3 0 obj\n<< /Length 5 >>\nstream\nHello\nendstream\nendobj\n';
      final bytes = Uint8List.fromList(content.codeUnits);
      final buffer = RandomAccessReadBuffer.fromBytes(bytes);
      final parser = COSParser(buffer);

      final offset = content.indexOf('3 0 obj');
      final streamObject = parser.parseIndirectObjectAt(offset)!;
      expect(streamObject.objectNumber, 3);
      final stream = streamObject.object as COSStream;
      expect(stream.data, equals(Uint8List.fromList('Hello'.codeUnits)));
    });
  });
}
