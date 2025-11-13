import 'dart:io';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_object_key.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/cos_parser.dart';
import 'package:test/test.dart';

void main() {
  group('BruteForceParser integration', () {
    late Uint8List hybridPdf;
    late Uint8List xrefStreamPdf;

    setUp(() {
      hybridPdf = File('test/resources/pdfparser/hybrid_broken_xref.pdf')
          .readAsBytesSync();
      xrefStreamPdf = File('test/resources/pdfparser/broken_xref_stream.pdf')
          .readAsBytesSync();
    });

    test('repairs hybrid xref/object streams with invalid offsets', () {
      final parser = COSParser(RandomAccessReadBuffer.fromBytes(hybridPdf));

      final document = parser.parseDocument();
      addTearDown(document.close);

      final root = document.trailer.getItem(COSName.root);
      expect(root, isNotNull,
          reason: 'Trailer should contain catalog reference');

      final catalogObject = document.getObjectByNumber(1);
      expect(catalogObject, isNotNull);
      expect(catalogObject!.object, isA<COSDictionary>());

      final compressedEntry = document.xrefTable[COSObjectKey(7, 0)];
      expect(compressedEntry, equals(-6),
          reason: 'Compressed object should reference object stream 6 0');

      final compressedObject = document.getObjectByNumber(7);
      expect(compressedObject, isNotNull);
      expect(
        (compressedObject!.object as COSDictionary)
            .getCOSName(COSName.subtype)
            ?.name,
        'Form',
      );
    });

    test('repairs misplaced xref stream offsets', () {
      final parser = COSParser(RandomAccessReadBuffer.fromBytes(xrefStreamPdf));

      final document = parser.parseDocument();
      addTearDown(document.close);

      expect(document.startXref, isNot(equals(42)));
      expect(document.getObjectByNumber(1), isNotNull);
      final pageDict = document.getObjectByNumber(3)?.object as COSDictionary;
      expect(pageDict.getCOSName(COSName.type)?.name, 'Page');
    });
  });
}
