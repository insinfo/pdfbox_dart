import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_type3_font.dart';
import 'package:test/test.dart';

void main() {
  group('PDType3Font', () {
    test('create from dictionary', () {
      final dict = COSDictionary();
      dict.setName(COSName.type, 'Font');
      dict.setName(COSName.subtype, 'Type3');
      
      // FontBBox
      final bbox = COSArray()
        ..add(COSFloat(0))
        ..add(COSFloat(0))
        ..add(COSFloat(1000))
        ..add(COSFloat(1000));
      dict.setItem(COSName.fontBBox, bbox);
      
      // FontMatrix
      final matrix = COSArray()
        ..add(COSFloat(0.001))
        ..add(COSFloat(0))
        ..add(COSFloat(0))
        ..add(COSFloat(0.001))
        ..add(COSFloat(0))
        ..add(COSFloat(0));
      dict.setItem(COSName.fontMatrix, matrix);
      
      // CharProcs
      final charProcs = COSDictionary();
      final streamA = COSStream();
      charProcs.setItem(COSName('a'), streamA);
      dict.setItem(COSName.charProcs, charProcs);
      
      // Encoding
      final encoding = COSDictionary();
      final differences = COSArray();
      differences.add(COSInteger(97));
      differences.add(COSName('a'));
      encoding.setItem(COSName.differences, differences);
      dict.setItem(COSName.encoding, encoding);
      
      // Widths
      dict.setInt(COSName.firstChar, 97);
      dict.setInt(COSName.lastChar, 97);
      final widths = COSArray();
      widths.add(COSFloat(500));
      dict.setItem(COSName.widths, widths);
      
      final font = PDType3Font(dict);
      
      expect(font.fontBBox!.lowerLeftX, 0);
      expect(font.fontBBox!.upperRightY, 1000);
      
      expect(font.fontMatrix.getValue(0, 0), 0.001);
      
      expect(font.getWidthFromFont(97), 500);
      
      final charStream = font.getCharStream(97);
      expect(charStream, isNotNull);
      expect(charStream, equals(streamA));
    });
  });
}

