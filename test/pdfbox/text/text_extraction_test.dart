import 'package:test/test.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_content_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_type1_font.dart';
import 'package:pdfbox_dart/src/pdfbox/text/pdf_text_stripper.dart';

void main() {
  group('PDF Text Extraction', () {
    test('Extract simple text', () async {
      // 1. Create a PDF with text
      final doc = PDDocument();
      final page = PDPage();
      doc.addPage(page);

      final font = PDType1Font.helvetica();
      final fontName = page.resources.addFont(font);

      final contentStream = PDPageContentStream(doc, page);

      contentStream.beginText();
      contentStream.setFont(fontName, 12);
      contentStream.newLineAtOffset(100, 700);
      contentStream.showText("Hello World!");
      contentStream.newLineAtOffset(0, -15);
      contentStream.showText("This is a test of PDF text extraction.");
      contentStream.endText();
      contentStream.close();

      // 2. Extract text
      final stripper = PDFTextStripper();
      final text = await stripper.getText(doc);

      doc.close();

      // 3. Verify
      // Note: PDFTextStripper usually adds newlines.
      // The exact output depends on the layout analysis.
      // Based on previous script output:
      // Hello World!
      // This is a test of PDF text extraction.
      
      expect(text, contains("Hello World!"));
      expect(text, contains("This is a test of PDF text extraction."));
    });
  });
}

