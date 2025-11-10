import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/ttf/ttf_parser.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffered_file.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_cid_font_type2_embedder.dart';
import 'package:test/test.dart';

void main() {
  group('PDCIDFontType2Embedder', () {
    test('builds Type 0 font dictionary with CIDFontType2 descendant', () {
      final parser = TtfParser();
      final randomAccess = RandomAccessReadBufferedFile(
        'resources/ttf/LiberationSans-Regular.ttf',
      );
      final font = parser.parse(randomAccess);
      addTearDown(() {
        font.close();
        randomAccess.close();
      });

      final embedder = PDCIDFontType2Embedder(trueTypeFont: font);
      embedder.addUnicode('A'.codeUnitAt(0));
      embedder.addUnicode('B'.codeUnitAt(0));
      embedder.addUnicode('C'.codeUnitAt(0));

      final result = embedder.build();

      final type0 = result.type0Dictionary;
      expect(type0.getNameAsString(COSName.subtype), 'Type0');
      expect(type0.getNameAsString(COSName.encoding), 'Identity-H');

      final descendants = type0.getCOSArray(COSName.descendantFonts);
      expect(descendants, isNotNull);
      expect(descendants, isA<COSArray>());
      expect(descendants!.length, equals(1));

      final cidFont = result.cidFontDictionary;
      expect(descendants[0], same(cidFont));
      expect(cidFont.getNameAsString(COSName.subtype), 'CIDFontType2');

      final descriptorDict = cidFont.getCOSDictionary(COSName.fontDescriptor);
      expect(descriptorDict, isNotNull);
      expect(result.fontDescriptor.cosObject, same(descriptorDict));

      final fontFile2 = descriptorDict!.getDictionaryObject(COSName.fontFile2);
      expect(fontFile2, isA<COSStream>());
      final embeddedData = (fontFile2 as COSStream).encodedBytes(copy: false);
      expect(embeddedData, isNotNull);
      expect(embeddedData, isNotEmpty);

      final toUnicode = type0.getDictionaryObject(COSName.toUnicode);
      expect(toUnicode, isA<COSStream>());
      final toUnicodeContent = String.fromCharCodes(
        (toUnicode as COSStream).encodedBytes(copy: false) ?? Uint8List(0),
      );
  expect(toUnicodeContent, contains('begincmap'));
  expect(toUnicodeContent, contains('<0041>'));

      final widths = cidFont.getCOSArray(COSName.w);
      expect(widths, isNotNull);
      final cidForA = _findCidForChar(result, font, 'A');
    final widthForA = _lookupWidth(widths!, cidForA)!;
    final expectedWidth =
      (font.getAdvanceWidth(cidForA) * 1000 / font.unitsPerEm).round();
    expect(widthForA, equals(expectedWidth));

      final cidToGid = cidFont.getDictionaryObject(COSName.cidToGidMap);
      expect(cidToGid, isA<COSStream>());
      final cidToGidBytes = (cidToGid as COSStream).encodedBytes(copy: false);
      expect(cidToGidBytes, isNotNull);
      final view = ByteData.sublistView(cidToGidBytes!);
      final mappedGid = view.getUint16(cidForA * 2, Endian.big);
      expect(mappedGid, equals(result.cidToGidMap[cidForA]));

      final cidSet = descriptorDict.getDictionaryObject(COSName.cidSet);
      expect(cidSet, isA<COSStream>());
      final cidSetBytes = (cidSet as COSStream).encodedBytes(copy: false);
      expect(cidSetBytes, isNotNull);
      expect(cidSetBytes!.isNotEmpty, isTrue);
    });
  });
}

int _findCidForChar(
  PDCIDFontType2EmbedderResult result,
  TrueTypeFont font,
  String character,
) {
  final glyphId = font.getUnicodeCmapLookup(isStrict: false)!
      .getGlyphId(character.codeUnitAt(0));
  final mapping = result.cidToGidMap;
  expect(mapping.containsKey(glyphId), isTrue,
      reason: 'Expected CID entry for glyph $glyphId');
  return glyphId;
}

int? _lookupWidth(COSArray widths, int cid) {
  for (var index = 0; index + 1 < widths.length; index += 2) {
    final start = widths[index] as COSInteger;
    final values = widths[index + 1] as COSArray;
    final offset = cid - start.intValue;
    if (offset >= 0 && offset < values.length) {
      final value = values[offset] as COSInteger;
      return value.intValue;
    }
  }
  return null;
}
