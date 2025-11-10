import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_document.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfwriter/pdf_save_options.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/cos_parser.dart';
import 'package:test/test.dart';

void main() {
  group('PDDocument', () {
    test('new document starts with empty page tree', () {
      final document = PDDocument();

      expect(document.numberOfPages, equals(0));

      final page = PDPage();
      document.addPage(page);

      expect(document.numberOfPages, equals(1));
      expect(document.getPage(0).mediaBox, equals(page.mediaBox));

      final removed = document.removePageAt(0);
      expect(identical(removed.cosObject, page.cosObject), isTrue);
      expect(document.numberOfPages, equals(0));

      document.close();
    });

    test('wraps existing COSDocument with nested page tree', () {
      final cosDocument = COSDocument();

      final root = COSDictionary()..setName(COSName.type, 'Catalog');
      final pages = COSDictionary()..setName(COSName.type, 'Pages');

      final childPages = COSDictionary()..setName(COSName.type, 'Pages');

      final inheritedBox = PDRectangle(0, 0, 200, 400).toCOSArray();
      childPages[COSName.mediaBox] = inheritedBox;

      final firstPage = PDPage().cosObject;
      final secondPage = PDPage().cosObject;

      firstPage.removeItem(COSName.mediaBox);

      final childKids = COSArray()..add(firstPage);
      childPages[COSName.kids] = childKids;

      final topKids = COSArray()
        ..add(childPages)
        ..add(secondPage);
      pages[COSName.kids] = topKids;

      root[COSName.pages] = pages;
      cosDocument.trailer[COSName.root] = root;

      final document = PDDocument.fromCOSDocument(cosDocument);

      expect(document.numberOfPages, equals(2));
      final page0 = document.getPage(0);
      final page1 = document.getPage(1);

      final expectedRect = PDRectangle.fromCOSArray(inheritedBox);
      expect(page0.mediaBox, equals(expectedRect));
      expect(page1.mediaBox, isNotNull);
      expect(page0.parent, isNotNull);
      expect(page1.parent, isNotNull);
      expect(document.indexOfPage(page1), equals(1));

      final removed = document.removePageAt(1);
      expect(identical(removed.cosObject, page1.cosObject), isTrue);
      expect(document.numberOfPages, equals(1));
      expect(pages.getInt(COSName.count), equals(1));

      document.close();
      cosDocument.close();
    });

    test('insert page maintains ordering', () {
      final document = PDDocument();
      final first = PDPage();
      final third = PDPage();
      document.addPage(first);
      document.addPage(third);

      final second = PDPage();
      document.insertPage(1, second);

      expect(document.numberOfPages, equals(3));
      final page1 = document.getPage(1);
      expect(identical(page1.cosObject, second.cosObject), isTrue);
      expect(document.getPage(0).parent, isNotNull);
      expect(document.getPage(2).parent, isNotNull);
      expect(document.documentCatalog.pages.count, equals(3));

      document.close();
    });

    test('newly added page receives resources and empty stream', () {
      final document = PDDocument();
      final page = PDPage();

      document.addPage(page);

      expect(page.cosObject.getDictionaryObject(COSName.resources), isNotNull);
      final streams = page.contentStreams.toList();
      expect(streams, hasLength(1));
      final data = streams.first.encodedBytes;
      expect(data, isNotNull);
      expect(data, isEmpty);

      document.close();
    });

    test('saveToBytes produces parseable PDF', () {
      final document = PDDocument();
      final page = PDPage();
      document.addPage(page);

      page.setContentStream(
        PDStream.fromBytes(Uint8List.fromList('BT ET'.codeUnits)),
      );

      final bytes = document.saveToBytes();
      expect(bytes, isNotEmpty);

      final source = RandomAccessReadBuffer.fromBytes(bytes);
      final parser = COSParser(source);
      final parsed = parser.parseDocument();
      expect(parsed.trailer.getDictionaryObject(COSName.root), isNotNull);
      expect(parsed.trailer.getInt(COSName.size), greaterThan(1));

      parsed.close();
      source.close();
      document.close();
    });

    test('saveToBytes can compress unfiltered streams', () {
      final document = PDDocument();
      final page = PDPage();
      document.addPage(page);

      final content = Uint8List.fromList(List<int>.filled(256, 42));
      page.setContentStream(PDStream.fromBytes(content));

      final withoutCompression = document.saveToBytes();
      final withCompression = document.saveToBytes(
        options: const PDFSaveOptions(compressStreams: true),
      );

      expect(withCompression.length, lessThan(withoutCompression.length));

      final compressedText = latin1.decode(withCompression, allowInvalid: true);
      expect(compressedText.contains('/Filter /FlateDecode'), isTrue);

      final uncompressedText =
          latin1.decode(withoutCompression, allowInvalid: true);
      expect(uncompressedText.contains('/Filter /FlateDecode'), isFalse);

      document.close();
    });
  });
}
