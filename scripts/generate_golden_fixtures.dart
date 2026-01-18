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
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_content_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';

void main() {
  final outDir = Directory('test/tmp/pdfs');
  outDir.createSync(recursive: true);

  _writeType3GlyphPdf(File('${outDir.path}/type3_glyph_retangulo_preto.pdf'));
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
