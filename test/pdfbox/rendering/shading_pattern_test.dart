import 'package:dart_graphics/dart_graphics.dart' show ImageBuffer;
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/pattern/pd_abstract_pattern.dart';
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
  test('PageDrawer: PatternType=2 shading pattern fills with axial shading',
      () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      // Function: red -> blue.
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

      // Axial shading dictionary (pattern space).
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
      shadingDict[COSName.function] = fn;

      // Shading pattern wrapper.
      final patternDict = COSDictionary();
      patternDict[COSName.type] = COSName.pattern;
      patternDict[COSName.patternType] = COSInteger(2);
      patternDict[COSName.shading] = shadingDict;
      patternDict[COSName.matrix] = COSArray()
        ..add(COSFloat(1))
        ..add(COSFloat(0))
        ..add(COSFloat(0))
        ..add(COSFloat(1))
        ..add(COSFloat(0))
        ..add(COSFloat(0));

      final pattern =
          PDAbstractPattern.create(patternDict, resources: page.resources);
      final patternName = page.resources.addPattern(pattern);

      final cs = PDPageContentStream(doc, page);
      cs.writeRaw('/Pattern cs\n/${patternName.name} scn\n');
      cs.rectangle(0, 0, 612, 792);
      cs.fill();
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);
      final y = _pxY(img, 100);

      final left = _getPixel(img, 10, y);
      final right = _getPixel(img, 602, y);

      expect(left.a, greaterThan(250));
      expect(left.r, greaterThan(200));
      expect(left.b, lessThan(60));

      expect(right.a, greaterThan(250));
      expect(right.b, greaterThan(200));
      expect(right.r, lessThan(60));
    } finally {
      doc.close();
    }
  });
}

