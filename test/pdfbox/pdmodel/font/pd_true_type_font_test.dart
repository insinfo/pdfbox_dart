import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_number.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_true_type_font.dart';
import 'package:test/test.dart';

void main() {
  group('PDTrueTypeFont', () {
    test('loads widths, unicode and dictionary entries from TrueType font file', () {
      final font = PDTrueTypeFont.fromFile(
        'resources/ttf/LiberationSans-Regular.ttf',
      );
      addTearDown(font.close);

      final dictionary = font.cosObject;
      expect(dictionary.getNameAsString(COSName.subtype), 'TrueType');
      expect(dictionary.getNameAsString(COSName.encoding), 'WinAnsiEncoding');
      final baseFont = dictionary.getNameAsString(COSName.baseFont);
      expect(baseFont, isNotEmpty);

      expect(font.firstChar, equals(32));
      expect(font.lastChar, equals(255));

      final widthsArray = dictionary.getCOSArray(COSName.widths);
      expect(widthsArray, isNotNull);
      expect(widthsArray, isA<COSArray>());
      final cosArray = widthsArray!;
      expect(cosArray.length, equals(font.lastChar - font.firstChar + 1));

      final cmap = font.trueTypeFont.getUnicodeCmapLookup(isStrict: false);
      expect(cmap, isNotNull);
      final gid = cmap!.getGlyphId('A'.codeUnitAt(0));
      expect(gid, greaterThan(0));

      final expectedWidth =
          font.trueTypeFont.getAdvanceWidth(gid) * 1000 / font.trueTypeFont.unitsPerEm;
      expect(font.getWidthFromFont(65), closeTo(expectedWidth, 1e-6));
      expect(font.toUnicode(65), 'A');

      final arrayIndex = 65 - font.firstChar;
      final widthFromDictionary =
          (cosArray[arrayIndex] as COSNumber).doubleValue;
      expect(widthFromDictionary, closeTo(expectedWidth, 1e-6));
      final widths = font.widths;
      expect(widths[arrayIndex], closeTo(expectedWidth, 1e-6));
      expect(() => widths[arrayIndex] = 0, throwsUnsupportedError);

      final descriptorDict = dictionary.getCOSDictionary(COSName.fontDescriptor);
      expect(descriptorDict, isNotNull);
      final descriptor = font.fontDescriptor;
      expect(descriptor.cosObject, same(descriptorDict));
      expect(descriptor.cosObject.getNameAsString(COSName.fontName), equals(baseFont));

      final bbox = descriptor.cosObject.getCOSArray(COSName.fontBBox);
      expect(bbox, isNotNull);
      expect(bbox!.length, equals(4));
      expect(descriptor.cosObject.getFloat(COSName.ascent), isNotNull);
      expect(descriptor.cosObject.getFloat(COSName.descent), isNotNull);
      expect(
        descriptor.cosObject.getFloat(COSName.missingWidth),
        closeTo(font.defaultGlyphWidth, 1e-6),
      );
    });

    test('builds subset and updates base font name with deterministic tag', () {
      final font = PDTrueTypeFont.fromFile(
        'resources/ttf/LiberationSans-Regular.ttf',
      );
      addTearDown(font.close);

      final originalBase = font.basePostScriptName;
      expect(originalBase, isNotEmpty);
      expect(font.needsSubset, isTrue);

      font.addStringToSubset('AB');
      font.addEncodedCodeToSubset(67); // add 'C'

      final subset = font.buildSubset();
      expect(subset.fontData.isEmpty, isFalse);
      expect(subset.tag, matches(RegExp(r'^[A-Z]{6}\+$')));

      final cmap = font.trueTypeFont.getUnicodeCmapLookup(isStrict: false);
      expect(cmap, isNotNull);
      final glyphId = cmap!.getGlyphId('A'.codeUnitAt(0));
      expect(subset.oldToNewGlyphId.containsKey(glyphId), isTrue);

      final updatedBaseName = font.cosObject.getNameAsString(COSName.baseFont);
      expect(updatedBaseName, equals('${subset.tag}$originalBase'));
      expect(font.basePostScriptName, equals(originalBase));

      final descriptorDict = font.fontDescriptor.cosObject;
      expect(descriptorDict.getNameAsString(COSName.fontName), updatedBaseName);
      final fontFile2 = descriptorDict.getDictionaryObject(COSName.fontFile2);
      expect(fontFile2, isA<COSStream>());
      final stream = fontFile2! as COSStream;
      final embeddedData = stream.encodedBytes();
      expect(embeddedData, isNotNull);
      expect(embeddedData, isNotEmpty);
      expect(embeddedData, equals(subset.fontData));
    });
  });
}
