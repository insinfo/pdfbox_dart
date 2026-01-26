
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_graphics/dart_graphics.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pdfont.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_resources.dart';
import 'package:pdfbox_dart/src/pdfbox/rendering/page_drawer.dart';
import 'package:pdfbox_dart/src/pdfbox/rendering/page_drawer_parameters.dart';
import 'package:pdfbox_dart/src/pdfbox/rendering/pdf_renderer.dart';
import 'package:pdfbox_dart/src/pdfbox/rendering/render_destination.dart';
import 'package:pdfbox_dart/src/pdfbox/contentstream/pd_content_stream.dart';
import 'package:pdfbox_dart/src/io/random_access_read.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:test/test.dart';

class NonVectorFont extends PDFont {
  NonVectorFont(super.dictionary);

  @override
  double getWidthFromFont(int code) => 500;

  @override
  String? toUnicode(int code) {
    if (code == 65) return 'A'; // 65 is 'A' in ASCII
    return null;
  }
  
  @override
  double getAverageFontWidth() => 500;
}

class MockPageDrawer extends PageDrawer {
  MockPageDrawer(super.parameters);
}

class MockContentStream implements PDContentStream {
  final RandomAccessRead reader;
  MockContentStream(this.reader);
  @override
  RandomAccessRead getContentsForStreamParsing() => reader;
}

void main() {
  group('Font Fallback', () {
    test('Fallback to embedded font for NonVectorFont', () {
      final doc = PDDocument();
      final pageDict = COSDictionary();
      pageDict.setName(COSName.type, 'Page');
      final page = PDPage(pageDict, doc.resourceCache);
      
      final renderer = PDFRenderer(doc);
      final params = PageDrawerParameters(
        renderer,
        page,
        false, // subsamplingAllowed
        RenderDestination.view,
        null, // details
        0.0 // optimization threshold (double)
      );
      
      final drawer = MockPageDrawer(params);
      final imageBuffer = ImageBuffer(100, 100);
      // drawer.drawPage call removed
      
      // Setup Resources
      final cache = page.resourceCache!;
      final fontDict = COSDictionary();
      fontDict.setName(COSName.type, 'Font');
      fontDict.setName(COSName.subtype, 'Type1');
      fontDict.setName(COSName.baseFont, 'Courier');
      
      final nonVectorFont = NonVectorFont(fontDict);
      cache.putFont(fontDict, nonVectorFont);
      
      final resources = PDResources(COSDictionary(), cache);
      resources.setFont(COSName.getPDFName('F1'), fontDict);
      pageDict[COSName.resources] = resources.cosObject;
      
      // 'A' is code 65.
      final stream = COSStream();
      stream.data = Uint8List.fromList('BT /F1 80 Tf 20 20 Td (A) Tj ET'.runes.toList());
      
      pageDict[COSName.contents] = stream;

      doc.addPage(page); // Add page to document so renderer can see it

      try {
        drawer.drawPage(imageBuffer.newGraphics2D(), PDRectangle(0, 0, 100, 100));
      } catch (e, st) {
          fail('Should not throw: $e\n$st');
      }
      
      // Check if any pixel was drawn. 
      // Starting from transparent (0,0,0,0), if we draw 'A' (black default), we should have some non-transparent pixels.
      final pixels = imageBuffer.getBuffer();
      bool hasDrawn = false;
      for (int i = 3; i < pixels.length; i+=4) {
          if (pixels[i] > 0) {
              hasDrawn = true;
              break;
          }
      }
      
      expect(hasDrawn, isTrue, reason: "Fallback font should render something");

      // Save the rendered image to a file for visual inspection
      final outputDir = Directory('test/tmp/actual');
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }
      final outputPath = '${outputDir.path}/font_fallback_test.png';
      renderer.renderImageToPngFile(0, outputPath, scale: 1.0);
    });
     });
}

