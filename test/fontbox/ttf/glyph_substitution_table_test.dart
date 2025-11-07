import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/cmap_subtable.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyph_substitution_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/language.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/substituting_cmap_lookup.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:test/test.dart';

void main() {
  group('GlyphSubstitutionTable parsing', () {
    test('table tag is exposed', () {
      expect(GlyphSubstitutionTable.tableTag, 'GSUB');
    });

    test('parses minimal single substitution table', () {
      final gsub = _loadMinimalGsubTable();
      expect(gsub.initialized, isTrue);
      expect(gsub.getSupportedScriptTags(), contains('latn'));
    });

    test('extracts GSUB data for supported scripts', () {
      final gsub = _loadMinimalGsubTable();
      final data = gsub.getGsubData();
      expect(data.language, Language.latin);
      expect(data.activeScriptName, 'latn');
      expect(data.getSupportedFeatures(), contains('liga'));

      final feature = data.getFeature('liga');
      expect(feature.canReplaceGlyphs(<int>[2]), isTrue);
      expect(feature.getReplacementForGlyphs(<int>[2]), equals(<int>[3]));
    });
  });

  group('Glyph substitution integration', () {
    test('SubstitutingCmapLookup applies GSUB substitution', () {
      final gsub = _loadMinimalGsubTable();
      final cmap = CmapSubtable()
        ..addMapping(0x66, 2); // 'f' -> glyph 2

      final lookup = SubstitutingCmapLookup(
        cmap,
        gsub,
        const <String>['liga'],
      );

      final glyphId = lookup.getGlyphId(0x66);
      expect(glyphId, 3);
      expect(lookup.getCharCodes(glyphId), equals(<int>[0x66]));
    });

    test('TrueTypeFont exposes registered GSUB table', () {
      final gsub = _loadMinimalGsubTable();
      final font = TrueTypeFont()..addTable(gsub);
      expect(font.getGsubTable(), same(gsub));
    });
  });
}

GlyphSubstitutionTable _loadMinimalGsubTable() {
  final table = GlyphSubstitutionTable()
    ..setTag(GlyphSubstitutionTable.tableTag)
    ..setLength(_minimalGsubTable.length)
    ..setOffset(0);

  final stream =
      RandomAccessReadDataStream.fromData(Uint8List.fromList(_minimalGsubTable));
  table.read(null, stream);
  stream.close();
  return table;
}

const List<int> _minimalGsubTable = <int>[
  // Header
  0x00, 0x01, // majorVersion
  0x00, 0x00, // minorVersion
  0x00, 0x0A, // scriptListOffset
  0x00, 0x1E, // featureListOffset
  0x00, 0x2C, // lookupListOffset
  // ScriptList (1 script: latn)
  0x00, 0x01, // scriptCount
  0x6C, 0x61, 0x74, 0x6E, // 'latn'
  0x00, 0x08, // scriptOffset
  0x00, 0x04, // defaultLangSysOffset
  0x00, 0x00, // langSysCount
  0x00, 0x00, // lookupOrder
  0xFF, 0xFF, // requiredFeatureIndex
  0x00, 0x01, // featureIndexCount
  0x00, 0x00, // featureIndices[0]
  // FeatureList (1 feature: liga)
  0x00, 0x01, // featureCount
  0x6C, 0x69, 0x67, 0x61, // 'liga'
  0x00, 0x08, // featureOffset
  0x00, 0x00, // featureParams
  0x00, 0x01, // lookupIndexCount
  0x00, 0x00, // lookupListIndices[0]
  // LookupList (1 lookup, single substitution)
  0x00, 0x01, // lookupCount
  0x00, 0x04, // lookupOffset
  0x00, 0x01, // lookupType = single substitution
  0x00, 0x00, // lookupFlag
  0x00, 0x01, // subTableCount
  0x00, 0x08, // subTableOffset
  0x00, 0x01, // substFormat = 1
  0x00, 0x06, // coverageOffset
  0x00, 0x01, // deltaGlyphID (+1)
  0x00, 0x01, // coverageFormat = 1
  0x00, 0x01, // glyphCount = 1
  0x00, 0x02, // glyphArray[0] = glyph 2
];
