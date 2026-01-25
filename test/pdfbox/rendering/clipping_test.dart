import 'package:dart_graphics/dart_graphics.dart' show ImageBuffer;
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_content_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/rendering/pdf_renderer.dart';

int _pixelIndex(ImageBuffer image, int x, int y) => (y * image.width + x) * 4;

({int r, int g, int b, int a}) _getPixel(ImageBuffer image, int x, int y) {
  final buf = image.getBuffer();
  final i = _pixelIndex(image, x, y);
  return (r: buf[i], g: buf[i + 1], b: buf[i + 2], a: buf[i + 3]);
}

int _pxX(double pdfX) => pdfX.round();

int _pxY(ImageBuffer image, double pdfY, {double pageHeight = 792}) {
  // Matches PDFRenderer base transform: y' = (ury - y) * scale.
  final py = (pageHeight - pdfY).round();
  return py.clamp(0, image.height - 1);
}

void main() {
  test('PageDrawer: clip W restricts subsequent painting', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      final cs = PDPageContentStream(doc, page);
      // Define clip rect.
      cs.rectangle(100, 100, 200, 200);
      cs.writeRaw('W\n');
      cs.writeRaw('n\n');

      // Paint a huge blue rectangle; should be clipped.
      cs.setNonStrokingColorRgb(0, 0, 1);
      cs.rectangle(0, 0, 612, 792);
      cs.fill();
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);

      final inside = _getPixel(img, _pxX(150), _pxY(img, 150));
      final outside = _getPixel(img, _pxX(50), _pxY(img, 50));

      expect(inside.b, greaterThan(200));
      expect(inside.r, lessThan(30));
      expect(inside.g, lessThan(30));

      expect(outside.r, greaterThan(240));
      expect(outside.g, greaterThan(240));
      expect(outside.b, greaterThan(240));
    } finally {
      doc.close();
    }
  });

  test('PageDrawer: clip W* (even-odd) produces a hole', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      final cs = PDPageContentStream(doc, page);
      // Outer + inner rectangles in one clipping path.
      cs.rectangle(100, 100, 300, 300);
      cs.rectangle(200, 200, 100, 100);
      cs.writeRaw('W*\n');
      cs.writeRaw('n\n');

      // Paint a huge blue rectangle; should be clipped with a hole.
      cs.setNonStrokingColorRgb(0, 0, 1);
      cs.rectangle(0, 0, 612, 792);
      cs.fill();
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);

      final inRing = _getPixel(img, _pxX(150), _pxY(img, 150));
      final inHole = _getPixel(img, _pxX(250), _pxY(img, 250));

      expect(inRing.b, greaterThan(200));
      expect(inRing.r, lessThan(30));
      expect(inRing.g, lessThan(30));

      // Hole should remain background (white).
      expect(inHole.r, greaterThan(240));
      expect(inHole.g, greaterThan(240));
      expect(inHole.b, greaterThan(240));
    } finally {
      doc.close();
    }
  });
}

