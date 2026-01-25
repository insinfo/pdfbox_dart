import 'dart:io';

import 'package:test/test.dart';
import 'package:pdfbox_dart/src/pdfbox/multipdf/splitter.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/io/random_access_write_file.dart';

void main() {
  group('Splitter', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pdf_splitter_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('split document with 2 pages into 2 documents', () {
      final doc = PDDocument();
      doc.addPage(PDPage()..mediaBox = PDRectangle.a4);
      doc.addPage(PDPage()..mediaBox = PDRectangle.a4);
      
      final splitter = Splitter();
      final documents = splitter.split(doc);
      
      expect(documents.length, 2);
      expect(documents[0].numberOfPages, 1);
      expect(documents[1].numberOfPages, 1);
      
      for (int i = 0; i < documents.length; i++) {
        final file = File('${tempDir.path}/split_$i.pdf');
        final output = RandomAccessWriteFile(file.path);
        documents[i].save(output);
        output.close();
        documents[i].close();
      }
      
      doc.close();
    });

    test('split document with 3 pages into documents of 2 pages', () {
      final doc = PDDocument();
      doc.addPage(PDPage()..mediaBox = PDRectangle.a4);
      doc.addPage(PDPage()..mediaBox = PDRectangle.a4);
      doc.addPage(PDPage()..mediaBox = PDRectangle.a4);
      
      final splitter = Splitter();
      splitter.setSplitAtPage(2);
      final documents = splitter.split(doc);
      
      expect(documents.length, 2);
      expect(documents[0].numberOfPages, 2);
      expect(documents[1].numberOfPages, 1);
      
      for (final d in documents) {
        d.close();
      }
      doc.close();
    });
  });
}

