import 'dart:io';
import 'dart:typed_data';

import 'package:dart_graphics/dart_graphics.dart' show ImageBuffer;
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/fontbox/ttf/cmap_lookup.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/ttf_parser.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_type0_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_content_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/rendering/pdf_renderer.dart';

String _hex2Bytes(int value) {
  final clamped = value & 0xFFFF;
  return clamped.toRadixString(16).padLeft(4, '0');
}

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

int _glyphIdForUnicode({required Uint8List ttfBytes, required int codePoint}) {
  final randomAccess = RandomAccessReadBuffer.fromBytes(ttfBytes);
  final ttf = TtfParser().parse(randomAccess);
  try {
    final CMapLookup? cmap = ttf.getUnicodeCmapLookup(isStrict: false);
    if (cmap == null) {
      throw StateError('No Unicode cmap available in test font');
    }
    return cmap.getGlyphId(codePoint);
  } finally {
    ttf.close();
  }
}

void main() {
  test('PageDrawer: text clip Tr=4 restricts subsequent painting', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      final ttfPath = 'resources/ttf/LiberationSans-Regular.ttf';
      final ttfBytes = File(ttfPath).readAsBytesSync();

      const letter = 'H';
      final glyphId = _glyphIdForUnicode(
        ttfBytes: ttfBytes,
        codePoint: letter.codeUnitAt(0),
      );
      expect(glyphId, greaterThan(0));

      // Ensure the subset includes the glyph we plan to reference.
      final font = PDType0Font.loadFromFile(
        doc,
        ttfPath,
        codePoints: <int>[letter.codeUnitAt(0)],
        embedSubset: true,
      );
      final COSName fontName = page.resources.addFont(font);

      final cs = PDPageContentStream(doc, page);
      cs.beginText();
      cs.setFont(fontName, 200);
      cs.setTextMatrix(1, 0, 0, 1, 100, 300);

      // Text rendering mode: clip only.
      cs.writeRaw('4 Tr\n');

      // Type0 Identity-H expects 2-byte codes; we use the original GID as CID.
      cs.writeRaw('<${_hex2Bytes(glyphId)}> Tj\n');
      cs.endText();

      // Now paint a full-page green rect; should be clipped to the glyph.
      cs.setNonStrokingColorRgb(0, 1, 0);
      cs.rectangle(0, 0, 612, 792);
      cs.fill();
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);

      final nonWhite = _countNonWhitePixels(img);
      final total = img.width * img.height;
      final ratio = nonWhite / total;

      // If clipping failed we'd paint almost the whole page.
      expect(ratio, lessThan(0.25));
      // If clipping worked we should still have some painted pixels.
      expect(ratio, greaterThan(0.001));
    } finally {
      doc.close();
    }
  });
}
