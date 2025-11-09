import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/ttf_parser.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/ttf_subsetter.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffered_file.dart';
import 'package:test/test.dart';

void main() {
  group('TtfSubsetter', () {
    late String liberationSans;

    setUpAll(() {
      liberationSans = _testFontPath('LiberationSans-Regular.ttf');
      if (!File(liberationSans).existsSync()) {
        fail('Test font missing at $liberationSans');
      }
    });

    test('builds empty subset retaining notdef glyph', () {
      final font = _parseFont(liberationSans);
      addTearDown(font.close);

      final subsetter = TtfSubsetter(font);
      final subset = _buildSubsetFont(subsetter.buildSubset());
      addTearDown(subset.close);

      expect(subset.numberOfGlyphs, 1);
      expect(subset.nameToGid('.notdef'), 0);

      final glyphTable = subset.getGlyphTable();
      expect(glyphTable, isNotNull);
      expect(glyphTable!.getGlyph(0), isNotNull);
    });

    test('builds empty subset with explicit table list', () {
      final font = _parseFont(liberationSans);
      addTearDown(font.close);

      final tables = <String>[
        'head',
        'hhea',
        'loca',
        'maxp',
        'cvt ',
        'prep',
        'glyf',
        'hmtx',
        'fpgm',
        'gasp'
      ];
      final subsetter = TtfSubsetter(font, tables);
      final subset = _buildSubsetFont(subsetter.buildSubset());
      addTearDown(subset.close);

      expect(subset.numberOfGlyphs, 1);
      expect(subset.nameToGid('.notdef'), 0);

      final glyphTable = subset.getGlyphTable();
      expect(glyphTable, isNotNull);
      expect(glyphTable!.getGlyph(0), isNotNull);
    });

    test('retains metrics for single glyph subset', () {
      final font = _parseFont(liberationSans);
      addTearDown(font.close);

      final subsetter = TtfSubsetter(font);
      subsetter.add('a'.codeUnitAt(0));

      final subset = _buildSubsetFont(subsetter.buildSubset());
      addTearDown(subset.close);

      expect(subset.numberOfGlyphs, 2);
      expect(subset.nameToGid('.notdef'), 0);
      expect(subset.nameToGid('a'), 1);

      final glyphTable = subset.getGlyphTable();
      expect(glyphTable, isNotNull);
      expect(glyphTable!.getGlyph(0), isNotNull);
      expect(glyphTable.getGlyph(1), isNotNull);
      expect(glyphTable.getGlyph(2), isNull);

      final fullAdvance = font.getAdvanceWidth(font.nameToGid('a'));
      final subsetAdvance = subset.getAdvanceWidth(subset.nameToGid('a'));
      expect(subsetAdvance, fullAdvance);

      final fullHmtx = font.getHorizontalMetricsTable();
      final subsetHmtx = subset.getHorizontalMetricsTable();
      expect(fullHmtx, isNotNull);
      expect(subsetHmtx, isNotNull);
      final fullLsb = fullHmtx!.getLeftSideBearing(font.nameToGid('a'));
      final subsetLsb = subsetHmtx!.getLeftSideBearing(subset.nameToGid('a'));
      expect(subsetLsb, fullLsb);
    });

    test('preserves postscript names for extended glyphs', () {
      final font = _parseFont(liberationSans);
      addTearDown(font.close);

      final subsetter = TtfSubsetter(font);
      subsetter.add('Ö'.codeUnitAt(0));
      subsetter.add(0x200A);

      final subset = _buildSubsetFont(subsetter.buildSubset());
      addTearDown(subset.close);

      expect(subset.numberOfGlyphs, 5);
      expect(subset.nameToGid('.notdef'), 0);
      expect(subset.nameToGid('O'), 1);
      expect(subset.nameToGid('Odieresis'), 2);
      expect(subset.nameToGid('uni200A'), 3);
      expect(subset.nameToGid('dieresis.uc'), 4);

      final post = subset.getPostScriptTable();
      expect(post, isNotNull);
      expect(post!.getName(0), '.notdef');
      expect(post.getName(1), 'O');
      expect(post.getName(2), 'Odieresis');
      expect(post.getName(3), 'uni200A');
      expect(post.getName(4), 'dieresis.uc');

      expect(subset.getPath('uni200A').isEmpty, isTrue);
      expect(subset.getPath('dieresis.uc').isEmpty, isFalse);
    });

    test('supports forcing invisible glyphs', () {
      final font = _parseFont(liberationSans);
      addTearDown(font.close);

      final subsetter = TtfSubsetter(font);
      subsetter.add('A'.codeUnitAt(0));
      subsetter.add('B'.codeUnitAt(0));
      subsetter.add(0x200C);

      final subset = _buildSubsetFont(subsetter.buildSubset());
      try {
        expect(subset.numberOfGlyphs, 4);
        expect(subset.nameToGid('A'), 1);
        expect(subset.nameToGid('B'), 2);
        expect(subset.nameToGid('uni200C'), 3);

        expect(subset.getPath('A').isEmpty, isFalse);
        expect(subset.getPath('B').isEmpty, isFalse);
        expect(subset.getPath('uni200C').isEmpty, isFalse);

        expect(subset.getWidth('A'), isNot(equals(0)));
        expect(subset.getWidth('B'), isNot(equals(0)));
        expect(subset.getWidth('uni200C'), equals(0));
      } finally {
        subset.close();
      }

      subsetter.forceInvisible('B'.codeUnitAt(0));
      subsetter.forceInvisible(0x200C);

      final forcedSubset = _buildSubsetFont(subsetter.buildSubset());
      addTearDown(forcedSubset.close);

      expect(forcedSubset.numberOfGlyphs, 4);
      expect(forcedSubset.nameToGid('A'), 1);
      expect(forcedSubset.nameToGid('B'), 2);
      expect(forcedSubset.nameToGid('uni200C'), 3);

      expect(forcedSubset.getPath('A').isEmpty, isFalse);
      expect(forcedSubset.getPath('B').isEmpty, isTrue);
      expect(forcedSubset.getPath('uni200C').isEmpty, isTrue);

      expect(forcedSubset.getWidth('A'), isNot(equals(0)));
      expect(forcedSubset.getWidth('B'), equals(0));
      expect(forcedSubset.getWidth('uni200C'), equals(0));
    });
  });
}

String _testFontPath(String name) {
  return p.join('resources', 'ttf', name);
}

TrueTypeFont _parseFont(String path) {
  final parser = TtfParser();
  final font = parser.parse(RandomAccessReadBufferedFile(path));
  font.getMaximumProfileTable();
  font.getIndexToLocationTable();
  if (font.numberOfGlyphs <= 0) {
    throw StateError('Font at $path reports no glyphs');
  }
  return font;
}

TrueTypeFont _buildSubsetFont(Uint8List data) {
  final parser = TtfParser(isEmbedded: true);
  return parser.parse(RandomAccessReadBuffer.fromBytes(data));
}
