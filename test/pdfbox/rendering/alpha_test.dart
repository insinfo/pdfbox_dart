import 'package:dart_graphics/dart_graphics.dart' show ImageBuffer;
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/state/pd_extended_graphics_state.dart';
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

int _pxY(ImageBuffer image, double pdfY, {double pageHeight = 792}) {
  final py = (pageHeight - pdfY).round();
  return py.clamp(0, image.height - 1);
}

void main() {
  test('PageDrawer: ExtGState ca applies non-stroking alpha', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      final gs = PDExtendedGraphicsState();
      // Non-stroking alpha constant: /ca
      gs.cosObject.setFloat(COSName.caNs, 0.5);
      final gsName = page.resources.addExtGState(gs);

      final cs = PDPageContentStream(doc, page);

      // Set semi-transparent red fill.
      cs.setNonStrokingColorRgb(1, 0, 0);
      cs.writeRaw('/${gsName.name} gs\n');
      cs.rectangle(100, 100, 200, 200);
      cs.fill();
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);

      final inside = _getPixel(img, 150, _pxY(img, 150));
      final outside = _getPixel(img, 50, _pxY(img, 50));

      // Background is white.
      expect(outside.r, greaterThan(240));
      expect(outside.g, greaterThan(240));
      expect(outside.b, greaterThan(240));

      // With alpha=0.5 over white, red channel stays ~255, green/blue ~128.
      expect(inside.r, greaterThan(240));
      expect(inside.g, inInclusiveRange(90, 170));
      expect(inside.b, inInclusiveRange(90, 170));
    } finally {
      doc.close();
    }
  });
}
