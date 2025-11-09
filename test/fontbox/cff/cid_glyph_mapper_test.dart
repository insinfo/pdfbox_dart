import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/cff/cid_glyph_mapper.dart';
import 'package:pdfbox_dart/src/fontbox/cmap/cmap.dart';
import 'package:pdfbox_dart/src/fontbox/cmap/codespace_range.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('CidGlyphMapper', () {
    test('maps encoded bytes to CID and glyph data', () {
      final font = createSimpleCidFont();
      final cmap = CMap();
      cmap.addCodespaceRange(CodespaceRange(
        Uint8List.fromList(<int>[0x00, 0x00]),
        Uint8List.fromList(<int>[0xff, 0xff]),
      ));
      cmap.addCIDMapping(Uint8List.fromList(<int>[0x00, 0x01]), 1);

      final mapper = CidGlyphMapper(font, cmap);
      final code = Uint8List.fromList(<int>[0x00, 0x01]);

      expect(mapper.toCid(code), equals(1));
      expect(mapper.toCidFromInt(0x0001, length: 2), equals(1));
      expect(mapper.toGid(code), equals(1));
      expect(mapper.hasGlyph(code), isTrue);
      expect(mapper.getWidth(code), closeTo(600, 1e-6));
      expect(mapper.getPath(code).commands, isNotEmpty);
    });

    test('decodes encoded strings into glyph mappings', () {
      final font = createSimpleCidFont();
      final cmap = CMap();
      cmap.addCodespaceRange(CodespaceRange(
        Uint8List.fromList(<int>[0x00, 0x00]),
        Uint8List.fromList(<int>[0xff, 0xff]),
      ));
      cmap.addCIDMapping(Uint8List.fromList(<int>[0x00, 0x01]), 1);
      cmap.addCIDMapping(Uint8List.fromList(<int>[0x00, 0x02]), 2);

      final mapper = CidGlyphMapper(font, cmap);
      final encoded = Uint8List.fromList(<int>[0x00, 0x01, 0x00, 0x02]);

      final glyphs = mapper.mapEncoded(encoded);
      expect(glyphs.length, equals(2));

      expect(glyphs.first.cid, equals(1));
      expect(glyphs.first.gid, equals(1));
      expect(glyphs.first.codeUnits, orderedEquals(<int>[0x00, 0x01]));
      expect(glyphs.first.width, closeTo(600, 1e-6));

      expect(glyphs.last.cid, equals(2));
      expect(glyphs.last.gid, equals(2));
      expect(glyphs.last.codeUnits, orderedEquals(<int>[0x00, 0x02]));
      expect(glyphs.last.width, closeTo(600, 1e-6));

      expect(mapper.decodeToCids(encoded), orderedEquals(<int>[1, 2]));
      expect(mapper.decodeToGids(encoded), orderedEquals(<int>[1, 2]));
      expect(
        mapper.decodeToWidths(encoded),
        everyElement(closeTo(600, 1e-6)),
      );
    });

    test('falls back to .notdef when mapping missing', () {
      final font = createSimpleCidFont();
      final cmap = CMap();
      cmap.addCodespaceRange(CodespaceRange(
        Uint8List.fromList(<int>[0x00]),
        Uint8List.fromList(<int>[0xff]),
      ));
      final mapper = CidGlyphMapper(font, cmap);
      final code = Uint8List.fromList(<int>[0x12]);

      expect(mapper.toCid(code), equals(0));
      expect(mapper.toGid(code), equals(0));
      expect(mapper.hasGlyph(code), isFalse);
      expect(mapper.getPath(code).commands, isEmpty);
      expect(mapper.getWidth(code), closeTo(1000, 1e-6));

      final glyphs = mapper.mapEncoded(code);
      expect(glyphs, hasLength(1));
      final entry = glyphs.single;
      expect(entry.cid, equals(0));
      expect(entry.gid, equals(0));
      expect(entry.isNotdef, isTrue);
      expect(entry.codeUnits, orderedEquals(<int>[0x12]));
      expect(entry.width, closeTo(1000, 1e-6));

      expect(mapper.decodeToCids(code), orderedEquals(<int>[0]));
      expect(mapper.decodeToGids(code), orderedEquals(<int>[0]));
      expect(mapper.decodeToWidths(code), orderedEquals(<double>[1000]));
    });
  });
}
