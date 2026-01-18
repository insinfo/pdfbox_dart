import 'package:dart_graphics/dart_graphics.dart' show ImageBuffer;
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_boolean.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/shading/pd_shading.dart';
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
  test(
      'PageDrawer: axial shading (ShadingType=2) renders gradient for sh operator',
      () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      // Build a simple axial shading from red (t=0) to blue (t=1), left->right.
      final fn = COSDictionary();
      fn[COSName.functionType] = COSInteger(2);
      fn[COSName.domain] = COSArray()
        ..add(COSFloat(0))
        ..add(COSFloat(1));
      fn[COSName.c0] = COSArray()
        ..add(COSFloat(1))
        ..add(COSFloat(0))
        ..add(COSFloat(0));
      fn[COSName.c1] = COSArray()
        ..add(COSFloat(0))
        ..add(COSFloat(0))
        ..add(COSFloat(1));
      fn[COSName.n] = COSFloat(1);

      final shadingDict = COSDictionary();
      shadingDict[COSName.shadingType] = COSInteger(2);
      shadingDict[COSName.colorSpace] = COSName.deviceRGB;
      shadingDict[COSName.coords] = COSArray()
        ..add(COSFloat(0))
        ..add(COSFloat(0))
        ..add(COSFloat(612))
        ..add(COSFloat(0));
      shadingDict[COSName.domain] = COSArray()
        ..add(COSFloat(0))
        ..add(COSFloat(1));
      shadingDict[COSName.extend] = COSArray()
        ..add(COSBoolean(true))
        ..add(COSBoolean(true));
      shadingDict[COSName.function] = fn;

      final shading = PDShading.create(shadingDict, resources: page.resources);
      final shadingName = page.resources.addShading(shading);

      final cs = PDPageContentStream(doc, page);
      cs.writeRaw('/${shadingName.name} sh\n');
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);

      final y = _pxY(img, 100);
      final left = _getPixel(img, 10, y);
      final mid = _getPixel(img, 306, y);
      final right = _getPixel(img, 602, y);

      expect(left.a, greaterThan(250));
      expect(left.r, greaterThan(220));
      expect(left.b, lessThan(40));

      expect(right.a, greaterThan(250));
      expect(right.b, greaterThan(220));
      expect(right.r, lessThan(40));

      // Midpoint should be purple-ish.
      expect(mid.a, greaterThan(250));
      expect(mid.r, inInclusiveRange(90, 170));
      expect(mid.b, inInclusiveRange(90, 170));
    } finally {
      doc.close();
    }
  });
}
