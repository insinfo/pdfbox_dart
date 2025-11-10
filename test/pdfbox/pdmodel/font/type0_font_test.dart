import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/cff/cff_charset.dart';
import 'package:pdfbox_dart/src/fontbox/cmap/cmap.dart';
import 'package:pdfbox_dart/src/fontbox/cmap/codespace_range.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/type0_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/cmap_manager.dart';
import 'package:test/test.dart';

import '../../../fontbox/cff/test_utils.dart';

void main() {
  group('Type0Font', () {
    test('decodes glyphs and unicode using encoding CMap', () {
      final font = createSimpleCidFont();
      final encoding = CMap();
      encoding.addCodespaceRange(CodespaceRange(
        Uint8List.fromList(<int>[0x00, 0x01]),
        Uint8List.fromList(<int>[0xff, 0xff]),
      ));
      encoding.addCIDMapping(Uint8List.fromList(<int>[0x00, 0x01]), 1);
      encoding.addCharMapping(Uint8List.fromList(<int>[0x00, 0x01]), 'a');

      final type0 = Type0Font(cidFont: font, encoding: encoding);
      final encoded = Uint8List.fromList(<int>[0x00, 0x01]);
      final glyphs = type0.decodeGlyphs(encoded);

      expect(glyphs, hasLength(1));
      final glyph = glyphs.single;
      expect(glyph.cid, equals(1));
      expect(glyph.gid, equals(1));
      expect(glyph.width, closeTo(600, 1e-6));
      expect(glyph.unicode, equals('a'));
  final bbox = type0.fontBoundingBox;
  expect(bbox.lowerLeftX, closeTo(-50, 1e-6));
  expect(bbox.upperRightY, closeTo(950, 1e-6));
  expect(type0.fontMatrix, orderedEquals(<num>[0.001, 0, 0, 0.001, 0, 0]));
      expect(type0.codeToCid(0x0001), equals(1));
      expect(type0.hasGlyphForCode(0x0001), isTrue);
      expect(type0.getPathForCode(0x0001).commands, isNotEmpty);
      expect(
        type0.getNormalizedPathForCode(0x0001).commands.length,
        equals(type0.getPathForCode(0x0001).commands.length),
      );
      expect(type0.decodeToUnicode(encoded), equals('a'));
      expect(type0.decodeCids(encoded), orderedEquals(<int>[1]));
      expect(type0.decodeGids(encoded), orderedEquals(<int>[1]));
    });

    test('prefers ToUnicode for Unicode resolution', () {
      final font = createSimpleCidFont();
      final encoding = CMap();
      encoding.addCodespaceRange(CodespaceRange(
        Uint8List.fromList(<int>[0x00, 0x01]),
        Uint8List.fromList(<int>[0xff, 0xff]),
      ));
      encoding.addCIDMapping(Uint8List.fromList(<int>[0x00, 0x02]), 2);
      encoding.addCharMapping(Uint8List.fromList(<int>[0x00, 0x02]), 'b');

      final toUnicode = CMap();
      toUnicode.addCodespaceRange(CodespaceRange(
        Uint8List.fromList(<int>[0x00, 0x02]),
        Uint8List.fromList(<int>[0x00, 0x02]),
      ));
      toUnicode.addCharMapping(Uint8List.fromList(<int>[0x00, 0x02]), 'β');

      final type0 = Type0Font(
        cidFont: font,
        encoding: encoding,
        toUnicode: toUnicode,
      );

      final encoded = Uint8List.fromList(<int>[0x00, 0x02]);
      final glyph = type0.decodeGlyphs(encoded).single;

      expect(glyph.unicode, equals('β'));
      expect(type0.decodeToUnicode(encoded), equals('β'));
    });

    test('yields notdef glyph when bytes are unmapped', () {
      final font = createSimpleCidFont();
      final encoding = CMap();
      encoding.addCodespaceRange(CodespaceRange(
        Uint8List.fromList(<int>[0x00, 0x01]),
        Uint8List.fromList(<int>[0xff, 0xff]),
      ));

      final type0 = Type0Font(cidFont: font, encoding: encoding);
      final glyphs = type0.decodeGlyphs(Uint8List.fromList(<int>[0x12, 0x34]));

      expect(glyphs, hasLength(1));
      final glyph = glyphs.single;
      expect(glyph.isNotdef, isTrue);
      expect(glyph.width, closeTo(1000, 1e-6));
      expect(type0.decodeToUnicode(Uint8List.fromList(<int>[0x12, 0x34])), isEmpty);
    });

    test('maps Unicode via UCS2 fallback for predefined CJK CMaps', () {
      final font = createSimpleCidFont()
        ..registry = 'Adobe'
        ..ordering = 'Japan1'
        ..supplement = 4;
      final encoding = CMapManager.getPredefinedCMap('UniJIS-UCS2-H');
      final ucs2 = CMapManager.getPredefinedCMap('Adobe-Japan1-UCS2');

      final encoded = Uint8List.fromList(<int>[0x00, 0x41]);
  final cid = encoding.toCID(encoded);
  expect(cid, greaterThan(0));
      expect(encoding.toUnicodeBytes(encoded), isNull);

      final charset = font.charset;
      expect(charset, isA<EmbeddedCharset>());
      (charset as EmbeddedCharset).addCID(1, cid);

      final type0 = Type0Font(cidFont: font, encoding: encoding);
      final glyph = type0.decodeGlyphs(encoded).single;

      final expectedUnicode = ucs2.toUnicode(cid);
      expect(expectedUnicode, isNotNull);
      expect(glyph.cid, equals(cid));
      expect(glyph.unicode, equals(expectedUnicode));
      expect(type0.decodeToUnicode(encoded), equals(expectedUnicode));
    });
  });
}
