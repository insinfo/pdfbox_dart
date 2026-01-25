import 'dart:io';

import 'package:test/test.dart';
import 'package:pdfbox_dart/src/pdfbox/multipdf/page_extractor.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/io/random_access_write_file.dart';

void main() {
  group('PageExtractor', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pdf_extractor_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('extract pages 2 to 3 from a 4 page document', () {
      final doc = PDDocument();
      doc.addPage(PDPage()..mediaBox = PDRectangle.a4); // Page 1
      doc.addPage(PDPage()..mediaBox = PDRectangle.a4); // Page 2
      doc.addPage(PDPage()..mediaBox = PDRectangle.a4); // Page 3
      doc.addPage(PDPage()..mediaBox = PDRectangle.a4); // Page 4
      
      final extractor = PageExtractor(doc, startPage: 2, endPage: 3);
      final extracted = extractor.extract();
      
      expect(extracted.numberOfPages, 2);
      
      final file = File('${tempDir.path}/extracted.pdf');
      final output = RandomAccessWriteFile(file.path);
      extracted.save(output);
      output.close();
      extracted.close();
      doc.close();
    });
  });
}

