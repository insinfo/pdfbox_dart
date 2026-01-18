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
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_type3_font.dart';
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

({int count, int minX, int minY, int maxX, int maxY}) _scanNonWhite(
    ImageBuffer image) {
  final buf = image.getBuffer();
  var count = 0;
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final i = (y * image.width + x) * 4;
      final r = buf[i];
      final g = buf[i + 1];
      final b = buf[i + 2];
      if (r != 255 || g != 255 || b != 255) {
        count++;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (count == 0) {
    return (count: 0, minX: 0, minY: 0, maxX: -1, maxY: -1);
  }
  return (count: count, minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

int _pxY(ImageBuffer image, double pdfY, {double pageHeight = 792}) {
  // The renderer maps PDF user-space (origin bottom-left) to image pixels
  // (origin top-left) via PDFRenderer's base transform.
  return (pageHeight - pdfY).round().clamp(0, image.height - 1);
}

void main() {
  test('PageDrawer: Type3 font renders glyph charprocs', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      // Build a minimal Type3 font where glyph 'A' paints a filled rectangle.
      final charProc = COSStream();
      charProc.data = Uint8List.fromList(utf8.encode('500 0 d0\n'
          '0 0 0 rg\n'
          '0 0 500 700 re f\n'));

      final charProcs = COSDictionary();
      charProcs[COSName('A')] = charProc;

      final fontDict = COSDictionary();
      fontDict[COSName.type] = COSName.font;
      fontDict[COSName.subtype] = COSName.type3;
      fontDict[COSName.nameKey] = COSName.getPDFName('FType3');
      fontDict[COSName.encoding] = COSName.standardEncoding;
      fontDict[COSName.charProcs] = charProcs;
      fontDict[COSName.resources] = COSDictionary();
      fontDict[COSName.fontBBox] = COSArray()
        ..add(COSFloat(0))
        ..add(COSFloat(0))
        ..add(COSFloat(500))
        ..add(COSFloat(700));
      fontDict[COSName.fontMatrix] = COSArray()
        ..add(COSFloat(0.001))
        ..add(COSFloat(0))
        ..add(COSFloat(0))
        ..add(COSFloat(0.001))
        ..add(COSFloat(0))
        ..add(COSFloat(0));
      fontDict[COSName.firstChar] = COSInteger(65);
      fontDict[COSName.lastChar] = COSInteger(65);
      fontDict[COSName.widths] = COSArray()..add(COSFloat(500));

      final type3Font = PDType3Font(fontDict);
      final fontName = page.resources.addFont(type3Font);

      final cs = PDPageContentStream(doc, page);
      cs.beginText();
      cs.setFont(fontName, 200);
      cs.setTextMatrix(1, 0, 0, 1, 100, 200);
      cs.showText('A');
      cs.endText();
      cs.close();

      final raw = page.contentStreams.first;
      final parsed = raw.getContentsForStreamParsing();
      try {
        parsed.seek(0);
        final allBytes = Uint8List(parsed.length);
        parsed.readFully(allBytes);
        final text = utf8.decode(allBytes);
        expect(text.contains('100 200 Tm'), isTrue,
            reason: 'Unexpected content stream: $text');
      } finally {
        parsed.close();
      }

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);

      expect(img.width, 612);
      expect(img.height, 792);

      final scan = _scanNonWhite(img);
      expect(scan.count, greaterThan(0),
          reason: 'Expected some painted pixels for Type3 glyph');

      // The filled rectangle ends up at x=[100..200], y=[200..340].
      final insideX = 150;
      final insideY = _pxY(img, 270);
      final inside = _getPixel(img, insideX, insideY);
      final outside = _getPixel(img, 50, _pxY(img, 50));

      expect(inside.a, greaterThan(250));
      expect(inside.r, lessThan(30),
          reason:
              'Painted bbox=${scan.minX},${scan.minY}..${scan.maxX},${scan.maxY}; '
              'sample=$insideX,$insideY');
      expect(inside.g, lessThan(30),
          reason:
              'Painted bbox=${scan.minX},${scan.minY}..${scan.maxX},${scan.maxY}; '
              'sample=$insideX,$insideY');
      expect(inside.b, lessThan(30),
          reason:
              'Painted bbox=${scan.minX},${scan.minY}..${scan.maxX},${scan.maxY}; '
              'sample=$insideX,$insideY');

      expect(outside.r, greaterThan(240));
      expect(outside.g, greaterThan(240));
      expect(outside.b, greaterThan(240));
    } finally {
      doc.close();
    }
  });
}
