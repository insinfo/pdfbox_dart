import 'package:dart_graphics/dart_graphics.dart' show ImageBuffer;
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/form/pd_form_xobject.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/state/pd_extended_graphics_state.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_form_content_stream.dart';
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
  test('PageDrawer: SMask /Alpha masks subsequent painting', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      // Build a transparency-group form XObject that paints a 50%-alpha rectangle.
      final form = PDFormXObject.forDocument(doc);
      form.boundingBox = page.mediaBox;

      final fcs = PDFormContentStream(form);

      final gsInForm = PDExtendedGraphicsState();
      gsInForm.cosObject.setFloat(COSName.caNs, 0.5);
      final gsInFormName = fcs.resources.addExtGState(gsInForm);
      fcs.writeRaw('/${gsInFormName.name} gs\n');
      fcs.setNonStrokingColor(0, 0, 0);
      fcs.rectangle(100, 100, 200, 200);
      fcs.fill();
      fcs.close();

      // Build the soft mask dictionary: /SMask << /S /Alpha /G <form-stream> >>
      final smaskDict = COSDictionary();
      smaskDict[COSName.s] = COSName.getPDFName('Alpha');
      smaskDict[COSName.g] = form.cosObject;

      final gs = PDExtendedGraphicsState();
      gs.cosObject[COSName.sMask] = smaskDict;
      final gsName = page.resources.addExtGState(gs);

      // Draw a full page green rectangle under the soft mask.
      final cs = PDPageContentStream(doc, page);
      cs.writeRaw('/${gsName.name} gs\n');
      cs.setNonStrokingColorRgb(0, 1, 0);
      cs.rectangle(0, 0, 612, 792);
      cs.fill();
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);

      final inside = _getPixel(img, 150, _pxY(img, 150));
      final outside = _getPixel(img, 50, _pxY(img, 50));

      // Outside mask should remain white.
      expect(outside.r, greaterThan(240));
      expect(outside.g, greaterThan(240));
      expect(outside.b, greaterThan(240));

      // Inside mask: green over white with alpha ~0.5 => (128,255,128).
      expect(inside.g, greaterThan(240));
      expect(inside.r, inInclusiveRange(90, 170));
      expect(inside.b, inInclusiveRange(90, 170));
    } finally {
      doc.close();
    }
  });

  test('PageDrawer: SMask /Luminosity masks subsequent painting', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      // Build a transparency-group form XObject that paints a 50% gray rectangle.
      // For /Luminosity, the mask is derived from RGB rather than alpha.
      final form = PDFormXObject.forDocument(doc);
      form.boundingBox = page.mediaBox;

      final fcs = PDFormContentStream(form);
      fcs.setNonStrokingColor(0.5, 0.5, 0.5);
      fcs.rectangle(100, 100, 200, 200);
      fcs.fill();
      fcs.close();

      // Build the soft mask dictionary: /SMask << /S /Luminosity /G <form-stream> >>
      final smaskDict = COSDictionary();
      smaskDict[COSName.s] = COSName.getPDFName('Luminosity');
      smaskDict[COSName.g] = form.cosObject;

      final gs = PDExtendedGraphicsState();
      gs.cosObject[COSName.sMask] = smaskDict;
      final gsName = page.resources.addExtGState(gs);

      // Draw a full page green rectangle under the soft mask.
      final cs = PDPageContentStream(doc, page);
      cs.writeRaw('/${gsName.name} gs\n');
      cs.setNonStrokingColorRgb(0, 1, 0);
      cs.rectangle(0, 0, 612, 792);
      cs.fill();
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);

      final inside = _getPixel(img, 150, _pxY(img, 150));
      final outside = _getPixel(img, 50, _pxY(img, 50));

      // Outside mask should remain white.
      expect(outside.r, greaterThan(240));
      expect(outside.g, greaterThan(240));
      expect(outside.b, greaterThan(240));

      // Inside mask: green over white with alpha ~0.5 => (128,255,128).
      expect(inside.g, greaterThan(240));
      expect(inside.r, inInclusiveRange(90, 170));
      expect(inside.b, inInclusiveRange(90, 170));
    } finally {
      doc.close();
    }
  });

  test('PageDrawer: SMask /Alpha applies /TR transfer function', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      // Soft mask group paints a 50%-alpha rectangle.
      final form = PDFormXObject.forDocument(doc);
      form.boundingBox = page.mediaBox;

      final fcs = PDFormContentStream(form);
      final gsInForm = PDExtendedGraphicsState();
      gsInForm.cosObject.setFloat(COSName.caNs, 0.5);
      final gsInFormName = fcs.resources.addExtGState(gsInForm);
      fcs.writeRaw('/${gsInFormName.name} gs\n');
      fcs.setNonStrokingColor(0, 0, 0);
      fcs.rectangle(100, 100, 200, 200);
      fcs.fill();
      fcs.close();

      // Transfer function: f(x) = x^2, so 0.5 -> 0.25.
      final tr = COSDictionary();
      tr[COSName.functionType] = COSInteger(2);
      tr[COSName.domain] = COSArray()
        ..add(COSInteger(0))
        ..add(COSInteger(1));
      tr[COSName.c0] = COSArray()..add(COSInteger(0));
      tr[COSName.c1] = COSArray()..add(COSInteger(1));
      tr[COSName.n] = COSInteger(2);

      final smaskDict = COSDictionary();
      smaskDict[COSName.s] = COSName.getPDFName('Alpha');
      smaskDict[COSName.g] = form.cosObject;
      smaskDict[COSName.tr] = tr;

      final gs = PDExtendedGraphicsState();
      gs.cosObject[COSName.sMask] = smaskDict;
      final gsName = page.resources.addExtGState(gs);

      final cs = PDPageContentStream(doc, page);
      cs.writeRaw('/${gsName.name} gs\n');
      cs.setNonStrokingColorRgb(0, 1, 0);
      cs.rectangle(0, 0, 612, 792);
      cs.fill();
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);
      final inside = _getPixel(img, 150, _pxY(img, 150));

      // With TR x^2, alpha ~0.25 => green over white => (191,255,191).
      expect(inside.g, greaterThan(240));
      expect(inside.r, inInclusiveRange(160, 220));
      expect(inside.b, inInclusiveRange(160, 220));
    } finally {
      doc.close();
    }
  });

  test('PageDrawer: SMask /Luminosity applies /BC outside group bbox', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      // Soft mask group bbox is small; inside it we paint black (mask=0).
      final form = PDFormXObject.forDocument(doc);
      form.boundingBox = PDRectangle(100, 100, 300, 300);

      final fcs = PDFormContentStream(form);
      fcs.setNonStrokingColor(0, 0, 0);
      fcs.rectangle(100, 100, 200, 200);
      fcs.fill();
      fcs.close();

      // Backdrop color = white => outside bbox multiplier = 1.
      final bc = COSArray()
        ..add(COSFloat(1.0))
        ..add(COSFloat(1.0))
        ..add(COSFloat(1.0));

      final smaskDict = COSDictionary();
      smaskDict[COSName.s] = COSName.getPDFName('Luminosity');
      smaskDict[COSName.g] = form.cosObject;
      smaskDict[COSName.bc] = bc;

      final gs = PDExtendedGraphicsState();
      gs.cosObject[COSName.sMask] = smaskDict;
      final gsName = page.resources.addExtGState(gs);

      final cs = PDPageContentStream(doc, page);
      cs.writeRaw('/${gsName.name} gs\n');
      cs.setNonStrokingColorRgb(0, 1, 0);
      cs.rectangle(0, 0, 612, 792);
      cs.fill();
      cs.close();

      final img = PDFRenderer(doc).renderImageWithScale(0, 1.0);

      final insideBBox = _getPixel(img, 150, _pxY(img, 150));
      final outsideBBox = _getPixel(img, 50, _pxY(img, 50));

      // Inside bbox: mask from black => suppress paint => stays white.
      expect(insideBBox.r, greaterThan(240));
      expect(insideBBox.g, greaterThan(240));
      expect(insideBBox.b, greaterThan(240));

      // Outside bbox: /BC white => full paint => green.
      expect(outsideBBox.g, greaterThan(240));
      expect(outsideBBox.r, lessThan(30));
      expect(outsideBBox.b, lessThan(30));
    } finally {
      doc.close();
    }
  });
}
