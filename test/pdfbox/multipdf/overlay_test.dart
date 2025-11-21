import 'dart:io';
import 'package:test/test.dart';
import 'package:pdfbox_dart/src/pdfbox/multipdf/overlay.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_content_stream.dart';
import 'package:pdfbox_dart/src/io/random_access_write_file.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';

void main() {
  group('Overlay', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pdf_overlay_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('overlay document', () {
      // Create input document
      final inputDoc = PDDocument();
      final page1 = PDPage()..mediaBox = PDRectangle.a4;
      inputDoc.addPage(page1);
      final page2 = PDPage()..mediaBox = PDRectangle.a4;
      inputDoc.addPage(page2);
      
      // Create overlay document
      final overlayDoc = PDDocument();
      final overlayPage = PDPage()..mediaBox = PDRectangle.a4;
      overlayDoc.addPage(overlayPage);
      
      final contentStream = PDPageContentStream(overlayDoc, overlayPage);
      contentStream.beginText();
      final fontName = COSName.getPDFName("Helv");
      overlayPage.resources.registerStandard14Font(fontName, "Helvetica");
      contentStream.setFont(fontName, 12);
      contentStream.newLineAtOffset(100, 100);
      contentStream.showText("Overlay Content");
      contentStream.endText();
      contentStream.close();
      
      final overlay = Overlay();
      overlay.inputPDF = inputDoc;
      overlay.defaultOverlayPDF = overlayDoc;
      overlay.overlay({});
      
      // Verify
      // Check if page 1 has the overlay
      // We expect to see /XO1 Do (or similar) in the content stream
      // Since we can't easily parse tokens without a parser exposed, we can check the raw stream content
      final p1Stream = page1.contentStreams.first;
      final p1Bytes = p1Stream.decode();
      final p1String = String.fromCharCodes(p1Bytes!);
      
      // The overlay adds "q ... /XO Do Q Q" or similar.
      // My implementation adds: q\nq\n ... /XO Do Q\nQ\n
      expect(p1String, contains('/XO Do'));
      
      final file = File('${tempDir.path}/overlaid.pdf');
      final output = RandomAccessWriteFile(file.path);
      inputDoc.save(output);
      output.close();
      
      inputDoc.close();
      overlayDoc.close();
      overlay.close();
    });
  });
}
