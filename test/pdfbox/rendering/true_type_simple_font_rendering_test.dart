import 'dart:io';

import 'package:dart_graphics/dart_graphics.dart' show ImageBuffer;
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_true_type_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_content_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/rendering/pdf_renderer.dart';

int _countNonWhitePixels(ImageBuffer image) {
  final buf = image.getBuffer();
  var count = 0;
  for (var i = 0; i < buf.length; i += 4) {
    if (buf[i] != 255 || buf[i + 1] != 255 || buf[i + 2] != 255) {
      count++;
    }
  }
  return count;
}

void main() {
  test('PageDrawer: TrueType simple font renders filled glyphs', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      final ttfPath = 'resources/ttf/LiberationSans-Regular.ttf';
      expect(File(ttfPath).existsSync(), isTrue,
          reason: 'Expected test TTF at $ttfPath');

      final ttfBytes = File(ttfPath).readAsBytesSync();
      final font = PDTrueTypeFont.fromFile(ttfPath, embedSubset: false);

      // Ensure the font program is embedded so the renderer can re-load it from
      // the COS dictionary via FontFile2.
      font.fontDescriptor.setFontFile2Data(ttfBytes);

      final fontName = page.resources.addFont(font);

      final cs = PDPageContentStream(doc, page);
      cs.beginText();
      cs.setFont(fontName, 160);
      cs.setTextMatrix(1, 0, 0, 1, 100, 320);
      cs.showText('HI');
      cs.endText();
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);

      final nonWhite = _countNonWhitePixels(img);
      expect(nonWhite, greaterThan(200),
          reason: 'Expected at least some painted pixels for text');

      // Sanity: top-left stays white.
      final buf = img.getBuffer();
      expect(buf[0], 255);
      expect(buf[1], 255);
      expect(buf[2], 255);
    } finally {
      doc.close();
    }
  });
}

