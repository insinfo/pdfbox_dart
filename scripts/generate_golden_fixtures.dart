import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_type3_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_type1_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_content_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_form_content_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/form/pd_transparency_group_attributes.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/form/pd_form_xobject.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/state/pd_extended_graphics_state.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/pdxobject.dart';

void main() {
  final outDir = Directory('test/tmp/pdfs');
  outDir.createSync(recursive: true);

  _writeType3GlyphPdf(File('${outDir.path}/type3_glyph_retangulo_preto.pdf'));
  _writeSoftMaskAlphaPdf(File('${outDir.path}/soft_mask_alpha.pdf'));
  _writeSoftMaskLuminosityPdf(File('${outDir.path}/soft_mask_luminosity.pdf'));
  _writeImageSoftMaskPdf(File('${outDir.path}/image_soft_mask.pdf'));
  _writeTextStripperBasicPdf(File('${outDir.path}/text_stripper_basic.pdf'));
}

void _writeType3GlyphPdf(File outFile) {
  final doc = PDDocument();
  try {
    final page = PDPage();
    // Keep fixtures tiny to speed up golden iteration.
    // 216pt = 3in. At 96dpi with scale=96/72, this becomes exactly 288px.
    final smallBox = PDRectangle(0, 0, 216, 216);
    page.mediaBox = smallBox;
    page.cropBox = smallBox;
    doc.addPage(page);

    // Minimal Type3 font where glyph 'A' paints a filled black rectangle.
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
    cs.setFont(fontName, 100);
    cs.setTextMatrix(1, 0, 0, 1, 30, 30);
    cs.showText('A');
    cs.endText();
    cs.close();

    final bytes = doc.saveToBytes();
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(bytes);
  } finally {
    doc.close();
  }
}

void _writeSoftMaskAlphaPdf(File outFile) {
  final doc = PDDocument();
  try {
    final page = PDPage();
    doc.addPage(page);

    final form = PDFormXObject.forDocument(doc);
    form.boundingBox = page.mediaBox;
    form.group = PDTransparencyGroupAttributes();

    final fcs = PDFormContentStream(form);
    final gsInForm = PDExtendedGraphicsState();
    gsInForm.cosObject.setFloat(COSName.caNs, 0.5);
    final gsInFormName = fcs.resources.addExtGState(gsInForm);
    fcs.writeRaw('/${gsInFormName.name} gs\n');
    fcs.setNonStrokingColor(0, 0, 0);
    fcs.rectangle(100, 100, 200, 200);
    fcs.fill();
    fcs.close();

    final smaskDict = COSDictionary();
    smaskDict[COSName.s] = COSName.getPDFName('Alpha');
    smaskDict[COSName.g] = form.cosObject;

    final gs = PDExtendedGraphicsState();
    gs.cosObject[COSName.sMask] = smaskDict;
    final gsName = page.resources.addExtGState(gs);

    final cs = PDPageContentStream(doc, page);
    cs.writeRaw('/${gsName.name} gs\n');
    cs.setNonStrokingColorRgb(0, 1, 0);
    cs.rectangle(0, 0, 612, 792);
    cs.fill();
    cs.close();

    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(doc.saveToBytes());
  } finally {
    doc.close();
  }
}

void _writeSoftMaskLuminosityPdf(File outFile) {
  final doc = PDDocument();
  try {
    final page = PDPage();
    doc.addPage(page);

    final form = PDFormXObject.forDocument(doc);
    form.boundingBox = page.mediaBox;
    form.group = PDTransparencyGroupAttributes();

    final fcs = PDFormContentStream(form);
    fcs.setNonStrokingColor(0.5, 0.5, 0.5);
    fcs.rectangle(100, 100, 200, 200);
    fcs.fill();
    fcs.close();

    final smaskDict = COSDictionary();
    smaskDict[COSName.s] = COSName.getPDFName('Luminosity');
    smaskDict[COSName.g] = form.cosObject;

    final gs = PDExtendedGraphicsState();
    gs.cosObject[COSName.sMask] = smaskDict;
    final gsName = page.resources.addExtGState(gs);

    final cs = PDPageContentStream(doc, page);
    cs.writeRaw('/${gsName.name} gs\n');
    cs.setNonStrokingColorRgb(0, 1, 0);
    cs.rectangle(0, 0, 612, 792);
    cs.fill();
    cs.close();

    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(doc.saveToBytes());
  } finally {
    doc.close();
  }
}

void _writeImageSoftMaskPdf(File outFile) {
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

    final cs = PDPageContentStream(doc, page);
    cs.writeRaw('q\n');
    cs.transform(20, 0, 0, 20, 100, 100);
    cs.drawImage(imageName);
    cs.writeRaw('Q\n');
    cs.close();

    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(doc.saveToBytes());
  } finally {
    doc.close();
  }
}

void _writeTextStripperBasicPdf(File outFile) {
  final doc = PDDocument();
  try {
    final page = PDPage();
    doc.addPage(page);

    final font = PDType1Font.helvetica();
    final fontName = page.resources.addFont(font);

    final cs = PDPageContentStream(doc, page);
    cs.beginText();
    cs.setFont(fontName, 12);
    cs.setLeading(14);
    cs.setTextMatrix(1, 0, 0, 1, 50, 700);
    cs.showText('Hello');
    cs.newLine();
    cs.showText('World');
    cs.endText();
    cs.close();

    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(doc.saveToBytes());
  } finally {
    doc.close();
  }
}

