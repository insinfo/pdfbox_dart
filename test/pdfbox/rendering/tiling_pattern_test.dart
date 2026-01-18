import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_graphics/dart_graphics.dart' show ImageBuffer;
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/pattern/pd_tiling_pattern.dart';
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
  test('PageDrawer: PatternType=1 tiling pattern fills with repeated tiles', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      // Build a simple 10x10 tiling pattern that paints a black stripe on the
      // left half of the cell.
      final pStream = COSStream();
      pStream[COSName.type] = COSName.pattern;
      pStream[COSName.patternType] = COSInteger(1);
      pStream[COSName.paintType] = COSInteger(1);
      pStream[COSName.tilingType] = COSInteger(1);
      pStream[COSName.bBox] = COSArray()
        ..add(COSFloat(0))
        ..add(COSFloat(0))
        ..add(COSFloat(10))
        ..add(COSFloat(10));
      pStream[COSName.xStep] = COSFloat(10);
      pStream[COSName.yStep] = COSFloat(10);
      pStream[COSName.resources] = COSDictionary();

      final content = '0 0 0 rg\n0 0 5 10 re f\n';
      pStream.data = Uint8List.fromList(utf8.encode(content));

      final pattern = PDTilingPattern(pStream, resources: page.resources);
      final patternName = page.resources.addPattern(pattern);

      // Paint a large rectangle using the pattern.
      final cs = PDPageContentStream(doc, page);
      cs.writeRaw('/Pattern cs\n/${patternName.name} scn\n');
      cs.rectangle(0, 0, 612, 792);
      cs.fill();
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);

      // Expect stripes: x=2 within black half, x=7 within transparent half.
      final y = _pxY(img, 100);
      final black = _getPixel(img, 2, y);
      final white = _getPixel(img, 7, y);

      expect(black.r, lessThan(30));
      expect(black.g, lessThan(30));
      expect(black.b, lessThan(30));

      expect(white.r, greaterThan(240));
      expect(white.g, greaterThan(240));
      expect(white.b, greaterThan(240));
    } finally {
      doc.close();
    }
  });
}
