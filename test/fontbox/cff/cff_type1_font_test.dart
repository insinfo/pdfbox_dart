import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/cff/cff_charset.dart';
import 'package:pdfbox_dart/src/fontbox/cff/cff_font.dart';
import 'package:pdfbox_dart/src/fontbox/cff/cff_standard_encoding.dart';
import 'package:test/test.dart';

void main() {
  group('CFFType1Font', () {
    test('exposes FontBoxFont contract', () {
      final font = _createType1Font();

      expect(font.getName(), equals('CFFType1'));
      expect(font.getEncoding(), isNotNull);
      expect(
        font.getFontMatrix(),
        orderedEquals(<num>[0.001, 0, 0, 0.001, 0, 0]),
      );

      final bbox = font.getFontBBox();
      expect(bbox.lowerLeftX, closeTo(-20, 1e-6));
      expect(bbox.lowerLeftY, closeTo(-200, 1e-6));
      expect(bbox.upperRightX, closeTo(1000, 1e-6));
      expect(bbox.upperRightY, closeTo(900, 1e-6));

      final path = font.getPath('A');
      expect(path.commands, isNotEmpty);

      final width = font.getWidth('A');
      expect(width, closeTo(600, 1e-6));

      expect(font.hasGlyph('A'), isTrue);
      expect(font.hasGlyph('Unknown'), isFalse);

      final fallback = font.getPath('Unknown');
      expect(fallback.commands, isEmpty);
    });

    test('caches Type2 charstrings by glyph identifier', () {
      final font = _createType1Font();

      final first = font.getType2CharString(1);
      final second = font.getType2CharString(1);
      expect(identical(first, second), isTrue);

      final fallback = font.getType2CharString(999);
      final fallbackAgain = font.getType2CharString(999);
      expect(identical(fallback, fallbackAgain), isTrue);
      expect(fallback.gidValue, equals(999));
      expect(fallback.getPath().commands, isEmpty);
    });
  });
}

CFFType1Font _createType1Font() {
  final font = CFFType1Font()
    ..name = 'CFFType1'
    ..charset = EmbeddedCharset(isCidFont: false)
    ..charStrings = <Uint8List>[]
    ..globalSubrIndex = <Uint8List>[];

  font.encoding = CFFStandardEncoding.instance;
  font.topDict['FontBBox'] = <num>[-20, -200, 1000, 900];
  font.topDict['FontMatrix'] = <num>[0.001, 0, 0, 0.001, 0, 0];

  final charset = font.charset as EmbeddedCharset;
  charset.addSID(0, 0, '.notdef');
  charset.addSID(1, 1, 'A');

  font.addPrivateEntry('defaultWidthX', 1000);
  font.addPrivateEntry('nominalWidthX', 0);
  font.addPrivateEntry('Subrs', <Uint8List>[]);

  final notdef = Uint8List.fromList(<int>[14]);
  final glyph =
      Uint8List.fromList(<int>[248, 236, 239, 247, 92, 21, 189, 6, 14]);
  font.charStrings = <Uint8List>[notdef, glyph];

  return font;
}
