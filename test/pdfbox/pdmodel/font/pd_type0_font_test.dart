import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/cmap/cmap.dart';
import 'package:pdfbox_dart/src/fontbox/cmap/codespace_range.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/ttf_parser.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffered_file.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_type0_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/type0_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:test/test.dart';

import '../../../fontbox/cff/test_utils.dart';

void main() {
  group('PDType0Font', () {
    test('builds Type 0 font dictionary and exposes Type0Font helper', () {
      final cidFont = createSimpleCidFont()
        ..registry = 'Adobe'
        ..ordering = 'Japan1'
        ..supplement = 4;

      final encoding = CMap()
        ..name = 'Identity-H';
      encoding.addCodespaceRange(
        CodespaceRange(
          Uint8List.fromList(<int>[0x00, 0x01]),
          Uint8List.fromList(<int>[0xff, 0xff]),
        ),
      );
      encoding.addCIDMapping(Uint8List.fromList(<int>[0x00, 0x01]), 1);
      encoding.addCharMapping(Uint8List.fromList(<int>[0x00, 0x01]), 'a');

      final type0 = Type0Font(cidFont: cidFont, encoding: encoding);
      final pdFont = PDType0Font.fromType0Font(
        baseFont: cidFont.name,
        type0Font: type0,
      );

      expect(pdFont.type0Font, same(type0));
      final bbox = pdFont.fontBoundingBox;
      expect(bbox, isNotNull);
      expect(bbox!.lowerLeftX, closeTo(-50, 1e-6));
      expect(pdFont.fontMatrix, isNotNull);
      expect(pdFont.fontMatrix, orderedEquals(<num>[0.001, 0, 0, 0.001, 0, 0]));
      final dictionary = pdFont.cosObject;
      expect(dictionary.getNameAsString(COSName.type), 'Font');
      expect(dictionary.getNameAsString(COSName.subtype), 'Type0');
      expect(dictionary.getNameAsString(COSName.baseFont), isNotEmpty);
      expect(dictionary.getNameAsString(COSName.encoding), 'Identity-H');

  expect(pdFont.isEmbedded, isFalse);
  expect(pdFont.isVertical, isFalse);
      expect(pdFont.isCMapPredefined, isTrue);
      expect(pdFont.isDescendantCjk, isTrue);

      final cidInfo = pdFont.cidSystemInfo;
      expect(cidInfo, isNotNull);
      expect(cidInfo!.ordering, 'Japan1');
      expect(pdFont.cMap, isNotNull);
      expect(pdFont.cMap!.name, 'Identity-H');
  expect(pdFont.cMapUcs2, isNotNull);
  expect(pdFont.cMapUcs2!.name, 'Adobe-Japan1-UCS2');

      final encoded = Uint8List.fromList(<int>[0x00, 0x01]);

      final reader = RandomAccessReadBuffer.fromBytes(encoded);
      try {
        expect(pdFont.readCode(reader), equals(1));
      } finally {
        reader.close();
      }

  final descendants = dictionary.getCOSArray(COSName.descendantFonts);
      expect(descendants, isNotNull);
  expect(descendants, isA<COSArray>());
      expect(descendants!.length, equals(1));
      expect(descendants[0], isA<COSDictionary>());

      final descendant = descendants[0] as COSDictionary;
      expect(descendant.getNameAsString(COSName.type), 'Font');
      expect(descendant.getNameAsString(COSName.subtype), 'CIDFontType0');
      expect(descendant.getNameAsString(COSName.baseFont), dictionary.getNameAsString(COSName.baseFont));

      final cidSystem = descendant.getCOSDictionary(COSName.cidSystemInfo);
      expect(cidSystem, isNotNull);
      expect(cidSystem!.getString(COSName.registry), 'Adobe');
      expect(cidSystem.getString(COSName.ordering), 'Japan1');
      expect(cidSystem.getInt(COSName.supplement), 4);

      final glyphs = pdFont.decodeGlyphs(encoded);
      expect(glyphs, hasLength(1));
      expect(glyphs.single.unicode, 'a');
      expect(pdFont.decodeToUnicode(encoded), 'a');

      expect(pdFont.getWidthFromFont(1), closeTo(600, 1e-6));
      expect(pdFont.toUnicode(1), 'a');
  expect(pdFont.codeToCid(1), equals(1));
  expect(pdFont.codeToGid(1), isNot(equals(0)));
  expect(pdFont.hasGlyph(1), isTrue);
    });

    test('embeds TrueType font as CIDFontType2 with ToUnicode stream', () {
      final parser = TtfParser();
      final randomAccess = RandomAccessReadBufferedFile(
        'resources/ttf/LiberationSans-Regular.ttf',
      );
      final trueTypeFont = parser.parse(randomAccess);
      addTearDown(() {
        trueTypeFont.close();
        randomAccess.close();
      });

      final font = PDType0Font.embedTrueTypeFont(
        trueTypeFont: trueTypeFont,
        codePoints: <int>['A'.codeUnitAt(0), 'B'.codeUnitAt(0)],
      );

      expect(font.hasType0FontHelper, isFalse);
      expect(font.isEmbedded, isTrue);
      expect(font.isVertical, isFalse);
      expect(font.cMap, isNotNull);
      expect(font.isCMapPredefined, isTrue);
      expect(font.fontDescriptor, isNotNull);
      final dictionary = font.cosObject;
      expect(dictionary.getNameAsString(COSName.type), 'Font');
      expect(dictionary.getNameAsString(COSName.subtype), 'Type0');
      expect(dictionary.getNameAsString(COSName.encoding), 'Identity-H');

      final descendants = dictionary.getCOSArray(COSName.descendantFonts);
      expect(descendants, isNotNull);
      expect(descendants, isA<COSArray>());
      final cidFont = descendants![0] as COSDictionary;
      expect(cidFont.getNameAsString(COSName.subtype), 'CIDFontType2');

      final fontDescriptor = cidFont.getCOSDictionary(COSName.fontDescriptor);
      expect(fontDescriptor, isNotNull);
      final fontFile2 = fontDescriptor!.getDictionaryObject(COSName.fontFile2);
      expect(fontFile2, isNotNull);

      final toUnicode = dictionary.getDictionaryObject(COSName.toUnicode);
      expect(toUnicode, isNotNull, reason: 'ToUnicode stream must be present');

      final embedResult = font.cidEmbedderResult;
      expect(embedResult, isNotNull);
      expect(embedResult!.isSubset, isTrue);
      expect(embedResult.subset, isNotNull);
      expect(embedResult.subset!.fontData, isNotEmpty);
      expect(embedResult.cidToGidMap, isNotEmpty);

      final firstCid = embedResult.cidToGidMap.keys.firstWhere((cid) => cid != 0);
      final unicode = font.toUnicode(firstCid);
      expect(unicode, isNotNull);
      expect(unicode!.length, equals(1));
      expect(font.codeToCid(firstCid), equals(firstCid));
      expect(font.codeToGid(firstCid), equals(embedResult.cidToGidMap[firstCid]));
      expect(font.hasGlyph(firstCid), isTrue);
    });

    test('embeds TrueType font in vertical mode when metrics available', () {
      final parser = TtfParser();
      final randomAccess = RandomAccessReadBufferedFile(
        'resources/ttf/LiberationSans-Regular.ttf',
      );
      final trueTypeFont = parser.parse(randomAccess);
      addTearDown(() {
        trueTypeFont.close();
        randomAccess.close();
      });

      final font = PDType0Font.embedTrueTypeFont(
        trueTypeFont: trueTypeFont,
        codePoints: const <int>[0x30B0],
        vertical: true,
      );

      final dictionary = font.cosObject;
      expect(dictionary.getNameAsString(COSName.encoding), 'Identity-V');
      expect(dictionary.getInt(COSName.wMode), 1);
      expect(font.isVertical, isTrue);
  expect(font.cMap, isNotNull);

      final toUnicode = dictionary.getDictionaryObject(COSName.toUnicode);
      expect(toUnicode, isNotNull, reason: 'ToUnicode stream must be present');

      final descendants = dictionary.getCOSArray(COSName.descendantFonts);
      expect(descendants, isNotNull);
      final cidFont = descendants![0] as COSDictionary;
      expect(cidFont.getNameAsString(COSName.subtype), 'CIDFontType2');
    });

    test('embeds TrueType font without subsetting', () {
      final parser = TtfParser();
      final randomAccess = RandomAccessReadBufferedFile(
        'resources/ttf/LiberationSans-Regular.ttf',
      );
      final trueTypeFont = parser.parse(randomAccess);
      addTearDown(() {
        trueTypeFont.close();
        randomAccess.close();
      });

      final font = PDType0Font.embedTrueTypeFont(
        trueTypeFont: trueTypeFont,
        embedSubset: false,
      );

      expect(font.isEmbedded, isTrue);
      final dictionary = font.cosObject;
      expect(dictionary.getNameAsString(COSName.encoding), 'Identity-H');

      final descendants = dictionary.getCOSArray(COSName.descendantFonts);
      expect(descendants, isNotNull);
      final cidFont = descendants![0] as COSDictionary;
      expect(cidFont.getDictionaryObject(COSName.cidToGidMap), COSName.identity);

      final fontDescriptor = cidFont.getCOSDictionary(COSName.fontDescriptor);
      expect(fontDescriptor, isNotNull);
      expect(fontDescriptor!.getDictionaryObject(COSName.fontFile2), isNotNull);

      final toUnicode = dictionary.getDictionaryObject(COSName.toUnicode);
      expect(toUnicode, isNotNull);

      final embedResult = font.cidEmbedderResult;
      expect(embedResult, isNotNull);
      expect(embedResult!.isSubset, isFalse);
      expect(embedResult.subset, isNull);
      expect(embedResult.cidToGidMap, isEmpty);
    });

    test('parses and embeds TrueType font from file path', () {
      final font = PDType0Font.fromTrueTypeFile(
        'resources/ttf/LiberationSans-Regular.ttf',
        codePoints: const <int>[65, 66],
      );

      final dictionary = font.cosObject;
      expect(dictionary.getNameAsString(COSName.subtype), 'Type0');
      final fontDescriptor =
          dictionary.getCOSArray(COSName.descendantFonts)![0] as COSDictionary;
      expect(
        fontDescriptor
            .getCOSDictionary(COSName.fontDescriptor)!
            .getDictionaryObject(COSName.fontFile2),
        isNotNull,
      );

      final embedResult = font.cidEmbedderResult;
      expect(embedResult, isNotNull);
      expect(embedResult!.isSubset, isTrue);
      expect(embedResult.subset!.oldToNewGlyphId, isNotEmpty);
    });

    test('parses and embeds TrueType font from in-memory data', () {
      final bytes = File('resources/ttf/LiberationSans-Regular.ttf').readAsBytesSync();
      final font = PDType0Font.fromTrueTypeData(
        bytes,
        codePoints: const <int>[67, 68],
      );

      final dictionary = font.cosObject;
      expect(dictionary.getNameAsString(COSName.subtype), 'Type0');
      final descendants = dictionary.getCOSArray(COSName.descendantFonts);
      expect(descendants, isNotNull);
      final cidFont = descendants![0] as COSDictionary;
      expect(
        cidFont.getCOSDictionary(COSName.fontDescriptor)!
            .getDictionaryObject(COSName.fontFile2),
        isNotNull,
      );

      final embedResult = font.cidEmbedderResult;
      expect(embedResult, isNotNull);
      expect(embedResult!.isSubset, isTrue);
      expect(embedResult.cidToGidMap, isNotEmpty);
    });

    test('embeds font selected from TrueType collection by index', () {
      final header = _buildSingleFontCollection();
      final font = PDType0Font.fromTrueTypeData(
        header.toBytes(),
        codePoints: const <int>[69, 70],
        collectionIndex: 0,
      );

      final descendants = font.cosObject.getCOSArray(COSName.descendantFonts);
      expect(descendants, isNotNull);
      final cidFont = descendants![0] as COSDictionary;
      expect(
        cidFont.getCOSDictionary(COSName.fontDescriptor)!
            .getDictionaryObject(COSName.fontFile2),
        isNotNull,
      );

      final embedResult = font.cidEmbedderResult;
      expect(embedResult, isNotNull);
      expect(embedResult!.isSubset, isTrue);
    });

    test('embeds font selected from TrueType collection by PostScript name', () {
      final header = _buildSingleFontCollection();
      final postScriptName = _lookupPostScriptName();
      expect(postScriptName, isNotNull, reason: 'LiberationSans must expose PostScript name');

      final font = PDType0Font.fromTrueTypeData(
        header.toBytes(),
        codePoints: const <int>[71, 72],
        collectionFontName: postScriptName,
      );

      final embedResult = font.cidEmbedderResult;
      expect(embedResult, isNotNull);
      expect(embedResult!.isSubset, isTrue);
    });

    test('loadFromFile uses PDDocument context', () {
      final document = PDDocument();
      addTearDown(document.close);

      final font = PDType0Font.loadFromFile(
        document,
        'resources/ttf/LiberationSans-Regular.ttf',
        codePoints: const <int>[65, 66],
      );

      final result = font.cidEmbedderResult;
      expect(result, isNotNull);
      expect(result!.isSubset, isTrue);
    });

    test('loadFromBytes supports font collections', () {
      final document = PDDocument();
      addTearDown(document.close);

      final header = _buildSingleFontCollection().toBytes();
      final font = PDType0Font.loadFromBytes(
        document,
        header,
        codePoints: const <int>[67, 68],
      );

      final result = font.cidEmbedderResult;
      expect(result, isNotNull);
      expect(result!.isSubset, isTrue);
    });

    test('loadFromStream reads asynchronous input', () async {
      final document = PDDocument();
      addTearDown(document.close);

      final bytes = File('resources/ttf/LiberationSans-Regular.ttf').readAsBytesSync();
      final chunks = [
        bytes.sublist(0, 64),
        bytes.sublist(64, 256),
        bytes.sublist(256),
      ];

      final font = await PDType0Font.loadFromStream(
        document,
        Stream<List<int>>.fromIterable(chunks),
        codePoints: const <int>[69, 70],
      );

      final result = font.cidEmbedderResult;
      expect(result, isNotNull);
      expect(result!.isSubset, isTrue);
    });

    test('loadVerticalFromTrueTypeFont sets vertical mode', () {
      final document = PDDocument();
      addTearDown(document.close);

      final parser = TtfParser();
      final randomAccess = RandomAccessReadBufferedFile(
        'resources/ttf/LiberationSans-Regular.ttf',
      );
      final trueTypeFont = parser.parse(randomAccess);
      addTearDown(() {
        trueTypeFont.close();
        randomAccess.close();
      });

      final font = PDType0Font.loadVerticalFromTrueTypeFont(
        document,
        trueTypeFont,
        codePoints: const <int>[0x30B0],
      );

      expect(font.cosObject.getNameAsString(COSName.encoding), 'Identity-V');
      expect(font.cosObject.getInt(COSName.wMode), 1);
    });
  });
}

Uint8List _u32be(int value) {
  final buffer = ByteData(4);
  buffer.setUint32(0, value);
  return buffer.buffer.asUint8List();
}

BytesBuilder _buildSingleFontCollection() {
  final original = File('resources/ttf/LiberationSans-Regular.ttf').readAsBytesSync();
  final adjusted = Uint8List.fromList(original);
  final numTables = ByteData.view(adjusted.buffer).getUint16(4);
  const collectionHeaderSize = 16;
  for (var i = 0; i < numTables; i++) {
    final recordOffset = 12 + i * 16;
    final tableView = ByteData.view(adjusted.buffer, recordOffset + 8, 4);
    final tableOffset = tableView.getUint32(0);
    tableView.setUint32(0, tableOffset + collectionHeaderSize);
  }

  final header = BytesBuilder();
  header.add(ascii.encode('ttcf'));
  header.add(_u32be(0x00010000));
  header.add(_u32be(1));
  header.add(_u32be(collectionHeaderSize));
  header.add(adjusted);
  return header;
}

String? _lookupPostScriptName() {
  final parser = TtfParser();
  final randomAccess = RandomAccessReadBuffer.fromBytes(
    File('resources/ttf/LiberationSans-Regular.ttf').readAsBytesSync(),
  );
  try {
    final font = parser.parse(randomAccess);
    try {
      return font.getNamingTable()?.getPostScriptName();
    } finally {
      font.close();
    }
  } finally {
    randomAccess.close();
  }
}
