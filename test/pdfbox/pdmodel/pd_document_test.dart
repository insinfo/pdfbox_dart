import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_document.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_object.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/documentnavigation/pd_outline_node.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfwriter/compress/compress_parameters.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfwriter/pdf_save_options.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/cos_parser.dart';
import 'package:test/test.dart';

String _headerFrom(Uint8List bytes) {
  final newlineIndex = bytes.indexOf(0x0a);
  final end = newlineIndex >= 0 ? newlineIndex : bytes.length;
  return latin1.decode(bytes.sublist(0, end), allowInvalid: true);
}

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

    test('document outline convenience delegates to catalog', () {
      final document = PDDocument();
      expect(document.documentOutline, isNull);

      final outline = PDOutlineRoot();
      document.documentOutline = outline;
      expect(document.documentOutline, same(outline));

      final bookmark = PDOutlineItem()..title = 'Bookmark';
      outline.addLast(bookmark);
      outline.open = true;
      expect(document.documentOutline?.openCount, 1);

      document.documentOutline = null;
      expect(document.documentOutline, isNull);
      expect(document.documentCatalog.cosObject.getDictionaryObject(COSName.outlines), isNull);
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
      expect(_headerFrom(bytes), equals('%PDF-1.7'));

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

    test('saveToBytes supports object stream compression', () {
      final document = PDDocument();
      final page = PDPage();
      document.addPage(page);

      final content = Uint8List.fromList(
        List<int>.generate(1024, (index) => index % 256),
      );
      page.setContentStream(PDStream.fromBytes(content));

      final uncompressed = document.saveToBytes();
      final compressed = document.saveToBytes(
        options: PDFSaveOptions(
          compressStreams: true,
          objectStreamCompression: const CompressParameters(),
        ),
      );

      final compressedText = latin1.decode(compressed, allowInvalid: true);
      expect(compressedText.contains('/Type /ObjStm'), isTrue);

      final reloaded = PDDocument.loadFromBytes(compressed);
      expect(reloaded.cosDocument.isXRefStream, isTrue);
      reloaded.close();

      // Ensure compression does not inflate file size compared to baseline.
      expect(compressed.length <= uncompressed.length + 64, isTrue);

      document.close();
    });

    test('saveToBytes preserves direct info dictionary state', () {
      final document = PDDocument();
      final info = document.documentInformation;
      final infoDict = info.cosObject
        ..isDirect = true;
      info.title = 'Direct Info';

      final bytes = document.saveToBytes();
      expect(bytes, isNotEmpty);
      expect(infoDict.isDirect, isTrue);

      document.close();
    });

    test('saveToBytes respects explicit PDF version', () {
      final document = PDDocument();
      document.version = '1.4';

      final page = PDPage();
      document.addPage(page);

      final bytes = document.saveToBytes();
      expect(_headerFrom(bytes), equals('%PDF-1.4'));

      document.close();
    });

    test('object stream compression bumps header to PDF 1.5', () {
      final document = PDDocument();
      document.version = '1.4';

      final page = PDPage();
      document.addPage(page);
      final content = Uint8List.fromList(List<int>.generate(512, (index) => index % 256));
      page.setContentStream(PDStream.fromBytes(content));

      final bytes = document.saveToBytes(
        options: PDFSaveOptions(
          compressStreams: true,
          objectStreamCompression: const CompressParameters(),
        ),
      );

      expect(_headerFrom(bytes), equals('%PDF-1.5'));
      expect(document.version, equals('1.5'));

      document.close();
    });

    test('saveToBytes promotes inline direct streams to indirect objects', () {
      final document = PDDocument();
      final page = PDPage();
      document.addPage(page);

      final metadata = COSStream()
        ..isDirect = true
        ..data = Uint8List.fromList(<int>[1, 2, 3, 4]);
      page.cosObject[COSName.metadata] = metadata;

      expect(metadata.isDirect, isTrue);

      document.saveToBytes();

      expect(metadata.isDirect, isTrue);
      final storedEntry = page.cosObject.getItem(COSName.metadata);
      expect(storedEntry, isA<COSObject>());
      final storedObject = storedEntry as COSObject;
      expect(storedObject.key, isNotNull);
      expect(identical(storedObject.object, metadata), isTrue);

      document.close();
    });

    test('saveIncremental promotes new inline streams before append', () {
      final document = PDDocument();
      final page = PDPage();
      document.addPage(page);

      final initial = document.saveToBytes();
      document.close();

      final reloaded = PDDocument.loadFromBytes(initial);
      final reloadedPage = reloaded.getPage(0);

      final metadata = COSStream()
        ..isDirect = true
        ..data = Uint8List.fromList(<int>[5, 6, 7]);
      reloadedPage.cosObject[COSName.metadata] = metadata;

      final original = RandomAccessReadBuffer.fromBytes(initial);
      final target = RandomAccessReadWriteBuffer();
      reloaded.saveIncremental(original, target);

      expect(metadata.isDirect, isTrue);
      expect(target.length, greaterThan(0));
      final storedEntry = reloadedPage.cosObject.getItem(COSName.metadata);
      expect(storedEntry, isA<COSObject>());
      final storedObject = storedEntry as COSObject;
      expect(storedObject.key, isNotNull);
      expect(identical(storedObject.object, metadata), isTrue);

      original.close();
      target.close();
      reloaded.close();
    });

  });
}
