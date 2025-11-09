import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyph_positioning_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/variation/variation_coordinate_provider.dart';
import 'package:test/test.dart';

void main() {
  test('parses pair positioning kerning from GPOS', () {
    final bytes = _buildMinimalPairPosTable();
    final stream = RandomAccessReadDataStream.fromData(bytes);
    final table = GlyphPositioningTable();
    table.setLength(bytes.length);
    table.read(null, stream);
    stream.close();

    expect(table.hasAdjustments, isTrue);
    expect(table.hasFeatureVariations, isFalse);
    expect(table.getKerningValue(10, 20), equals(-50));
    expect(table.getKerningValue(20, 10), equals(0));
  });

  test('parses class-based pair positioning kerning from GPOS', () {
    final bytes = _buildMinimalPairPosTable(_buildPairPosFormat2());
    final stream = RandomAccessReadDataStream.fromData(bytes);
    final table = GlyphPositioningTable();
    table.setLength(bytes.length);
    table.read(null, stream);
    stream.close();

    expect(table.hasAdjustments, isTrue);
    expect(table.getKerningValue(10, 20), equals(-80));
    expect(table.getKerningValue(11, 20), equals(0));
    expect(table.getKerningValue(10, 21), equals(0));
  });

  test('GlyphPositioningExecutor applies pair positioning adjustments', () {
    final bytes = _buildMinimalPairPosTable();
    final stream = RandomAccessReadDataStream.fromData(bytes);
    final table = GlyphPositioningTable();
    table.setLength(bytes.length);
    table.read(null, stream);
    stream.close();

    final executor = table.createExecutor();
    final adjustments = executor.apply(<int>[10, 20]);

    expect(adjustments, hasLength(2));
    expect(adjustments[0].xAdvance, equals(-50));
    expect(adjustments[1].isZero, isTrue);
  });

  test('Feature variations keep default lookup when axis is below threshold', () {
    final bytes = _buildGposWithFeatureVariations(
      defaultAdvance: -50,
      alternateAdvance: -120,
    );
    final stream = RandomAccessReadDataStream.fromData(bytes);
    final table = GlyphPositioningTable();
    table.setLength(bytes.length);
    table.read(_VariationCoordinatesStub(const <double>[0.0]), stream);
    stream.close();

    final executor = table.createExecutor();
    final adjustments = executor.apply(
      <int>[10, 20],
      scriptTags: const <String>['DFLT'],
      enabledFeatures: const <String>['kern'],
    );

    expect(adjustments[0].xAdvance, equals(-50));
    expect(adjustments[1].isZero, isTrue);
  });

  test('Feature variations swap to alternate lookup when axis matches range', () {
    final bytes = _buildGposWithFeatureVariations(
      defaultAdvance: -50,
      alternateAdvance: -160,
    );
    final stream = RandomAccessReadDataStream.fromData(bytes);
    final table = GlyphPositioningTable();
    table.setLength(bytes.length);
    table.read(_VariationCoordinatesStub(const <double>[1.0]), stream);
    stream.close();

    final executor = table.createExecutor();
    final adjustments = executor.apply(
      <int>[10, 20],
      scriptTags: const <String>['DFLT'],
      enabledFeatures: const <String>['kern'],
    );

    expect(adjustments[0].xAdvance, equals(-160));
    expect(adjustments[1].isZero, isTrue);
  });
}

Uint8List _buildMinimalPairPosTable([Uint8List? pairPos]) {
  final scriptList = _buildScriptList();
  final featureList = _buildFeatureList();
  final pairData = pairPos ?? _buildPairPosFormat1();
  final lookupList = _buildLookupList(pairData);

  final builder = BytesBuilder();
  builder.add(_u16(1)); // majorVersion
  builder.add(_u16(0)); // minorVersion
  builder.add(_u16(10)); // scriptListOffset
  builder.add(_u16(10 + scriptList.length)); // featureListOffset
  builder.add(
      _u16(10 + scriptList.length + featureList.length)); // lookupListOffset
  builder.add(scriptList);
  builder.add(featureList);
  builder.add(lookupList);
  return builder.toBytes();
}

Uint8List _buildScriptList() {
  final builder = BytesBuilder();
  builder.add(_u16(1)); // scriptCount
  builder.add(_tag('DFLT'));
  builder.add(_u16(8)); // offset to script table
  builder.add(_u16(4)); // defaultLangSysOffset
  builder.add(_u16(0)); // langSysCount
  builder.add(_u16(0)); // lookupOrder
  builder.add(_u16(0xFFFF)); // requiredFeatureIndex
  builder.add(_u16(1)); // featureIndexCount
  builder.add(_u16(0)); // featureIndices[0]
  return builder.toBytes();
}

Uint8List _buildFeatureList() {
  final builder = BytesBuilder();
  builder.add(_u16(1)); // featureCount
  builder.add(_tag('kern'));
  builder.add(_u16(8)); // feature offset
  builder.add(_u16(0)); // featureParams
  builder.add(_u16(1)); // lookupIndexCount
  builder.add(_u16(0)); // lookupListIndices[0]
  return builder.toBytes();
}

Uint8List _buildLookupList(Uint8List pairPos) {
  final lookup = _buildPairPosLookup(pairPos);
  return _buildLookupListWithPairLookups(<Uint8List>[lookup]);
}

Uint8List _buildLookupListWithPairLookups(List<Uint8List> pairLookups) {
  final builder = BytesBuilder();
  builder.add(_u16(pairLookups.length));
  final headerSize = 2 + pairLookups.length * 2;
  var nextOffset = headerSize;
  for (final lookup in pairLookups) {
    builder.add(_u16(nextOffset));
    nextOffset += lookup.length;
  }
  for (final lookup in pairLookups) {
    builder.add(lookup);
  }
  return builder.toBytes();
}

Uint8List _buildPairPosFormat1([int xAdvance = -50]) {
  final builder = BytesBuilder();
  builder.add(_u16(1)); // posFormat
  builder.add(_u16(18)); // coverageOffset
  builder.add(_u16(0x0004)); // valueFormat1 (xAdvance)
  builder.add(_u16(0)); // valueFormat2
  builder.add(_u16(1)); // pairSetCount
  builder.add(_u16(12)); // pairSetOffsets[0]
  builder.add(_u16(1)); // pairValueCount
  builder.add(_u16(20)); // secondGlyph
  builder.add(_i16(xAdvance)); // valueRecord1.xAdvance
  builder.add(_u16(1)); // coverage format
  builder.add(_u16(1)); // glyph count
  builder.add(_u16(10)); // glyph id
  return builder.toBytes();
}

Uint8List _buildPairPosFormat2() {
  final builder = BytesBuilder();
  builder.add(_u16(2)); // posFormat
  builder.add(_u16(44)); // coverageOffset
  builder.add(_u16(0x0004)); // valueFormat1 (xAdvance)
  builder.add(_u16(0)); // valueFormat2
  builder.add(_u16(24)); // classDef1Offset
  builder.add(_u16(34)); // classDef2Offset
  builder.add(_u16(2)); // class1Count (classes 0 and 1)
  builder.add(_u16(2)); // class2Count (classes 0 and 1)
  builder.add(_i16(0)); // class1=0, class2=0
  builder.add(_i16(0)); // class1=0, class2=1
  builder.add(_i16(0)); // class1=1, class2=0
  builder.add(_i16(-80)); // class1=1, class2=1
  builder.add(_u16(1)); // class definition format
  builder.add(_u16(10)); // startGlyphId
  builder.add(_u16(2)); // glyphCount
  builder.add(_u16(1)); // glyph 10 -> class 1
  builder.add(_u16(0)); // glyph 11 -> class 0
  builder.add(_u16(2)); // class definition format
  builder.add(_u16(1)); // classRangeCount
  builder.add(_u16(20)); // startGlyphId
  builder.add(_u16(20)); // endGlyphId
  builder.add(_u16(1)); // class value
  builder.add(_u16(1)); // coverage format
  builder.add(_u16(1)); // glyphCount
  builder.add(_u16(10)); // glyph id
  return builder.toBytes();
}

Uint8List _buildGposWithFeatureVariations({
  required int defaultAdvance,
  required int alternateAdvance,
}) {
  final scriptList = _buildScriptList();
  final featureList = _buildFeatureList();
  final defaultLookup =
      _buildPairPosLookup(_buildPairPosFormat1(defaultAdvance));
  final alternateLookup =
      _buildPairPosLookup(_buildPairPosFormat1(alternateAdvance));
  final lookupList = _buildLookupListWithPairLookups(
    <Uint8List>[defaultLookup, alternateLookup],
  );
  final featureVariations = _buildFeatureVariationsBlock();

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

Uint8List _buildPairPosLookup(Uint8List subtable) {
  final builder = BytesBuilder();
  builder.add(_u16(2)); // lookupType (PairPos)
  builder.add(_u16(0)); // lookupFlag
  builder.add(_u16(1)); // subTableCount
  builder.add(_u16(8)); // subtable offset
  builder.add(subtable);
  return builder.toBytes();
}

Uint8List _buildFeatureVariationsBlock() {
  final builder = BytesBuilder();
  builder.add(_u32(1)); // record count
  builder.add(_u32(12)); // conditionSetOffset
  builder.add(_u32(24)); // featureTableSubstitutionOffset

  builder.add(_u16(1)); // conditionCount
  builder.add(_u16(4)); // offset to first condition
  builder.add(_u16(1)); // conditionFormat
  builder.add(_u16(0)); // axisIndex
  builder.add(_i16(4096)); // minValue (0.25)
  builder.add(_i16(16384)); // maxValue (1.0)

  builder.add(_u16(1)); // substitutionCount
  builder.add(_u16(0)); // featureIndex
  builder.add(_u16(6)); // alternateOffset
  builder.add(_u16(0)); // featureParams
  builder.add(_u16(1)); // lookupIndexCount
  builder.add(_u16(1)); // lookupListIndices[0] (alternate lookup)
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
