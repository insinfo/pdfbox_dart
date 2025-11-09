import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/cmap_subtable.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyph_substitution_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/language.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/jstf/jstf_lookup_control.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/substituting_cmap_lookup.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/variation/variation_coordinate_provider.dart';
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

    test('getGsubDataForScript returns data for explicit script tag', () {
      final gsub = _loadMinimalGsubTable();
      final data = gsub.getGsubDataForScript('latn');
      expect(data, isNotNull);
      expect(data!.language, Language.unspecified);
      expect(data.activeScriptName, 'latn');
      expect(data.getSupportedFeatures(), contains('liga'));
    });
  });

  group('Glyph substitution integration', () {
    test('SubstitutingCmapLookup applies GSUB substitution', () {
      final gsub = _loadMinimalGsubTable();
      final cmap = CmapSubtable()..addMapping(0x66, 2); // 'f' -> glyph 2

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

    test('returns original glyph id when unsubstitution misses lookup', () {
      final gsub = _loadMinimalGsubTable();
      expect(gsub.getUnsubstitution(99), 99);
    });

    test('respects JSTF disabled lookups during substitution', () {
      final gsub = _loadMinimalGsubTable();
      final control = JstfLookupControl(disabledGsubLookups: <int>{0});
      final substituted = gsub.getSubstitution(
        2,
        const <String>['latn'],
        const <String>['liga'],
        jstfControl: control,
      );
      expect(substituted, 2);
    });

    test('Feature variations keep default GSUB lookup when axis is below range', () {
      final gsub = _loadGsubWithFeatureVariations(const <double>[0.0]);
      final substituted = gsub.getSubstitution(
        10,
        const <String>['DFLT'],
        const <String>['liga'],
      );
      expect(substituted, 11);
    });

    test('Feature variations enable alternate GSUB lookup when axis matches range', () {
      final gsub = _loadGsubWithFeatureVariations(const <double>[1.0]);
      final substituted = gsub.getSubstitution(
        10,
        const <String>['DFLT'],
        const <String>['liga'],
      );
      expect(substituted, 12);
    });
  });
}

GlyphSubstitutionTable _loadMinimalGsubTable() {
  final table = GlyphSubstitutionTable()
    ..setTag(GlyphSubstitutionTable.tableTag)
    ..setLength(_minimalGsubTable.length)
    ..setOffset(0);

  final stream = RandomAccessReadDataStream.fromData(
      Uint8List.fromList(_minimalGsubTable));
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

GlyphSubstitutionTable _loadGsubWithFeatureVariations(
    List<double> normalizedCoordinates) {
  final bytes = _buildGsubWithFeatureVariations(
    defaultDelta: 1,
    alternateDelta: 2,
  );
  final table = GlyphSubstitutionTable()
    ..setTag(GlyphSubstitutionTable.tableTag)
    ..setLength(bytes.length)
    ..setOffset(0);

  final stream = RandomAccessReadDataStream.fromData(bytes);
  table.read(_VariationCoordinatesStub(normalizedCoordinates), stream);
  stream.close();
  return table;
}

Uint8List _buildGsubWithFeatureVariations({
  required int defaultDelta,
  required int alternateDelta,
}) {
  final scriptList = _buildGsubScriptList();
  final featureList = _buildGsubFeatureList();
  final defaultLookup = _buildSingleSubstitutionLookup(defaultDelta);
  final alternateLookup = _buildSingleSubstitutionLookup(alternateDelta);
  final lookupList =
      _buildGsubLookupList(<Uint8List>[defaultLookup, alternateLookup]);
  final featureVariations = _buildGsubFeatureVariationsBlock();

  const headerSize = 14;
  final scriptListOffset = headerSize;
  final featureListOffset = scriptListOffset + scriptList.length;
  final lookupListOffset = featureListOffset + featureList.length;
  final featureVariationsOffset = lookupListOffset + lookupList.length;

  final builder = BytesBuilder();
  builder
    ..add(_u16(1))
    ..add(_u16(1))
    ..add(_u16(scriptListOffset))
    ..add(_u16(featureListOffset))
    ..add(_u16(lookupListOffset))
    ..add(_u32(featureVariationsOffset))
    ..add(scriptList)
    ..add(featureList)
    ..add(lookupList)
    ..add(featureVariations);
  return builder.toBytes();
}

Uint8List _buildGsubScriptList() {
  final builder = BytesBuilder();
  builder.add(_u16(1));
  builder.add(_tag('DFLT'));
  builder.add(_u16(8));
  builder.add(_u16(4));
  builder.add(_u16(0));
  builder.add(_u16(0));
  builder.add(_u16(0xFFFF));
  builder.add(_u16(1));
  builder.add(_u16(0));
  return builder.toBytes();
}

Uint8List _buildGsubFeatureList() {
  final builder = BytesBuilder();
  builder.add(_u16(1));
  builder.add(_tag('liga'));
  builder.add(_u16(8));
  builder.add(_u16(0));
  builder.add(_u16(1));
  builder.add(_u16(0));
  return builder.toBytes();
}

Uint8List _buildGsubLookupList(List<Uint8List> lookups) {
  final builder = BytesBuilder();
  builder.add(_u16(lookups.length));
  final headerSize = 2 + lookups.length * 2;
  var nextOffset = headerSize;
  for (final lookup in lookups) {
    builder.add(_u16(nextOffset));
    nextOffset += lookup.length;
  }
  for (final lookup in lookups) {
    builder.add(lookup);
  }
  return builder.toBytes();
}

Uint8List _buildSingleSubstitutionLookup(int delta) {
  final builder = BytesBuilder();
  builder.add(_u16(1)); // lookupType
  builder.add(_u16(0)); // lookupFlag
  builder.add(_u16(1)); // subTableCount
  builder.add(_u16(8)); // subtable offset
  builder.add(_u16(1)); // substFormat
  builder.add(_u16(6)); // coverageOffset
  builder.add(_i16(delta)); // deltaGlyphId
  builder.add(_u16(1)); // coverageFormat
  builder.add(_u16(1)); // glyphCount
  builder.add(_u16(10)); // glyph id
  return builder.toBytes();
}

Uint8List _buildGsubFeatureVariationsBlock() {
  final builder = BytesBuilder();
  builder.add(_u32(1));
  builder.add(_u32(12));
  builder.add(_u32(24));
  builder.add(_u16(1));
  builder.add(_u16(4));
  builder.add(_u16(1));
  builder.add(_u16(0));
  builder.add(_i16(4096));
  builder.add(_i16(16384));
  builder.add(_u16(1));
  builder.add(_u16(0));
  builder.add(_u16(6));
  builder.add(_u16(0));
  builder.add(_u16(1));
  builder.add(_u16(1));
  return builder.toBytes();
}

List<int> _u16(int value) => <int>[(value >> 8) & 0xFF, value & 0xFF];

List<int> _i16(int value) {
  final encoded = value & 0xFFFF;
  return _u16(encoded);
}

List<int> _u32(int value) => <int>[
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

List<int> _tag(String value) {
  assert(value.length == 4);
  return value.codeUnits;
}

class _VariationCoordinatesStub implements VariationCoordinateProvider {
  const _VariationCoordinatesStub(this.coordinates);

  final List<double> coordinates;

  @override
  List<double> get normalizedVariationCoordinates => coordinates;
}
