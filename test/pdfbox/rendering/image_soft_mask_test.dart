import 'dart:io';
import 'dart:typed_data';

import 'package:dart_graphics/dart_graphics.dart' show ImageBuffer;
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_content_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_true_type_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/pdxobject.dart';
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
  test('PageDrawer: image SMask applies per-pixel alpha', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      final imageStream = COSStream()
        ..setName(COSName.type, COSName.xObject.name)
        ..setName(COSName.subtype, COSName.image.name)
        ..setInt(COSName.width, 1)
        ..setInt(COSName.height, 1)
        ..setInt(COSName.bitsPerComponent, 8)
        ..setName(COSName.colorSpace, COSName.deviceRGB.name)
        ..data = Uint8List.fromList(<int>[255, 0, 0]);

      final blueImageStream = COSStream()
        ..setName(COSName.type, COSName.xObject.name)
        ..setName(COSName.subtype, COSName.image.name)
        ..setInt(COSName.width, 1)
        ..setInt(COSName.height, 1)
        ..setInt(COSName.bitsPerComponent, 8)
        ..setName(COSName.colorSpace, COSName.deviceRGB.name)
        ..data = Uint8List.fromList(<int>[0, 0, 255]);

      final greenImageStream = COSStream()
        ..setName(COSName.type, COSName.xObject.name)
        ..setName(COSName.subtype, COSName.image.name)
        ..setInt(COSName.width, 1)
        ..setInt(COSName.height, 1)
        ..setInt(COSName.bitsPerComponent, 8)
        ..setName(COSName.colorSpace, COSName.deviceRGB.name)
        ..data = Uint8List.fromList(<int>[0, 255, 0]);

      final maskStream = COSStream()
        ..setName(COSName.type, COSName.xObject.name)
        ..setName(COSName.subtype, COSName.image.name)
        ..setInt(COSName.width, 1)
        ..setInt(COSName.height, 1)
        ..setInt(COSName.bitsPerComponent, 8)
        ..setName(COSName.colorSpace, COSName.deviceGray.name)
        ..data = Uint8List.fromList(<int>[128]);

      imageStream[COSName.sMask] = maskStream;

        final image = PDImageXObject.fromCOSStream(imageStream,
          resources: page.resources);
        final imageName = page.resources.add(image, 'Im');
        final blueImage = PDImageXObject.fromCOSStream(blueImageStream,
          resources: page.resources);
        final blueImageName = page.resources.add(blueImage, 'ImB');
        final greenImage = PDImageXObject.fromCOSStream(greenImageStream,
          resources: page.resources);
        final greenImageName = page.resources.add(greenImage, 'ImG');

      final cs = PDPageContentStream(doc, page);
      // Draw a blue image near bottom-left.
      cs.writeRaw('q\n');
      cs.transform(20, 0, 0, 20, 50, 50);
      cs.drawImage(blueImageName);
      cs.writeRaw('Q\n');

      // Draw a green image near top-left.
      cs.writeRaw('q\n');
      cs.transform(20, 0, 0, 20, 50, 700);
      cs.drawImage(greenImageName);
      cs.writeRaw('Q\n');

      // Draw letter N to verify text rendering.
      final font = PDTrueTypeFont.fromFile('resources/ttf/LiberationSans-Regular.ttf');
      final fontName = page.resources.addFont(font);
      cs.setNonStrokingColorRgb(0, 0, 0);
      cs.beginText();
      cs.setFont(fontName, 48);
      cs.setTextMatrix(1, 0, 0, 1, 200, 400);
      cs.showText('N');
      cs.endText();

      cs.writeRaw('q\n');
      cs.transform(1, 0, 0, 1, 100, 100);
      cs.drawImage(imageName);
      cs.writeRaw('Q\n');
      cs.close();

      final renderer = PDFRenderer(doc);
      final img = renderer.renderImageWithScale(0, 1.0);
      final outputDir = Directory('test/tmp/actual');
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }
      final outputPath = '${outputDir.path}/image_soft_mask_actual.png';
      renderer.renderImageToPngFile(0, outputPath, scale: 1.0);
      final inside = _getPixel(img, 100, _pxY(img, 100));
      final outside = _getPixel(img, 50, _pxY(img, 50));
      final expectedX = 100;
      final expectedY = _pxY(img, 100);
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final px = (expectedX + dx).clamp(0, img.width - 1);
          final py = (expectedY + dy).clamp(0, img.height - 1);
          _getPixel(img, px, py);
        }
      }
      var minX = img.width;
      var minY = img.height;
      var maxX = -1;
      var maxY = -1;
      for (var y = 0; y < img.height; y++) {
        for (var x = 0; x < img.width; x++) {
          final p = _getPixel(img, x, y);
          if (p.r < 250 || p.g < 250 || p.b < 250) {
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x > maxX) maxX = x;
            if (y > maxY) maxY = y;
          }
        }
      }
      
      // Find the red blended pixel (should be around 100, 691-692)
      // The SMask causes red (255,0,0) with alpha 128 to blend with white
      // Result: r=255, g=127, b=127 (blended over white)
      ({int r, int g, int b, int a})? redBlendedPixel;
      for (var y = _pxY(img, 101); y <= _pxY(img, 99); y++) {
        for (var x = 99; x <= 101; x++) {
          final p = _getPixel(img, x.clamp(0, img.width - 1), y.clamp(0, img.height - 1));
          // Looking for red blended with white: high R, medium G, medium B
          if (p.r > 200 && p.g > 100 && p.g < 180 && p.b > 100 && p.b < 180) {
            redBlendedPixel = p;
            break;
          }
        }
        if (redBlendedPixel != null) break;
      }
      
      final insideSample = redBlendedPixel ?? inside;

      // Scan a small region where the text should appear.
      final textMinX = 190;
      final textMaxX = 260;
      final textMinY = _pxY(img, 420);
      final textMaxY = _pxY(img, 360);
      for (var y = textMaxY; y <= textMinY; y++) {
        for (var x = textMinX; x <= textMaxX; x++) {
          final p = _getPixel(img, x.clamp(0, img.width - 1),
              y.clamp(0, img.height - 1));
          if (p.r < 250 || p.g < 250 || p.b < 250) {
          }
        }
      }

      expect(outside.r, greaterThan(240));
      expect(outside.g, greaterThan(240));
      expect(outside.b, greaterThan(240));

      expect(insideSample.r, greaterThan(240));
      expect(insideSample.g, inInclusiveRange(90, 170));
      expect(insideSample.b, inInclusiveRange(90, 170));
    } finally {
      doc.close();
    }
  });
}

