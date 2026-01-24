import 'dart:io';

import 'package:test/test.dart';
import 'package:pdfbox_dart/src/pdfbox/multipdf/pdf_merger_utility.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/io/random_access_write_file.dart';

void main() {
  group('PDFMergerUtility', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pdf_merger_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('merge two documents with one page each', () {
      final doc1 = PDDocument();
      doc1.addPage(PDPage()..mediaBox = PDRectangle.a4);
      final file1 = File('${tempDir.path}/doc1.pdf');
      final output1 = RandomAccessWriteFile(file1.path);
      doc1.save(output1);
      output1.close();
      doc1.close();

      final doc2 = PDDocument();
      doc2.addPage(PDPage()..mediaBox = PDRectangle.a4);
      final file2 = File('${tempDir.path}/doc2.pdf');
      final output2 = RandomAccessWriteFile(file2.path);
      doc2.save(output2);
      output2.close();
      doc2.close();

      final merger = PDFMergerUtility();
      merger.addSource(file1);
      merger.addSource(file2);
      final destFile = File('${tempDir.path}/merged.pdf');
      merger.setDestinationFileName(destFile.path);
      merger.mergeDocuments();

      final mergedDoc = PDDocument.loadFile(destFile.path);
      expect(mergedDoc.numberOfPages, 2);
      mergedDoc.close();
    });

    test('merge two documents with optimize mode', () {
      final doc1 = PDDocument();
      doc1.addPage(PDPage()..mediaBox = PDRectangle.a4);
      final file1 = File('${tempDir.path}/doc1_opt.pdf');
      final output1 = RandomAccessWriteFile(file1.path);
      doc1.save(output1);
      output1.close();
      doc1.close();

      final doc2 = PDDocument();
      doc2.addPage(PDPage()..mediaBox = PDRectangle.a4);
      final file2 = File('${tempDir.path}/doc2_opt.pdf');
      final output2 = RandomAccessWriteFile(file2.path);
      doc2.save(output2);
      output2.close();
      doc2.close();

      final merger = PDFMergerUtility();
      merger.addSource(file1);
      merger.addSource(file2);
      merger.setDocumentMergeMode(DocumentMergeMode.optimizeResourcesMode);
      final destFile = File('${tempDir.path}/merged_opt.pdf');
      merger.setDestinationFileName(destFile.path);
      merger.mergeDocuments();

      final mergedDoc = PDDocument.loadFile(destFile.path);
      expect(mergedDoc.numberOfPages, 2);
      mergedDoc.close();
    });
  });
}
