import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/cmap_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyph_data.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyph_renderer.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyph_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/header_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/gsub_data.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/post_script_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/jstf/jstf_lookup_control.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/otl_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/wgl4_names.dart';
import 'package:test/test.dart';

void main() {
  test('unicode cmap lookup and glyph name resolution', () {
    final font = TrueTypeFont(glyphCount: Wgl4Names.numberOfMacGlyphs);

    final cmapTable = _buildFormat0CmapTable(font, codePoint: 0x41, glyphId: 2);
    final postTable = _buildFormat1PostTable(font);

    font.addTable(cmapTable);
    font.addTable(postTable);

    final lookup = font.getUnicodeCmapLookup();
    expect(lookup, isNotNull);
    expect(lookup!.getGlyphId(0x41), 2);

    expect(font.nameToGid('A'), greaterThan(0));
    expect(font.nameToGid('uni0041'), 2);
    expect(font.nameToGid('g3'), 3);
    expect(font.nameToGid('unknown'), 0);

    expect(font.hasGlyph('A'), isTrue);
    expect(font.hasGlyph('unknown'), isFalse);

    expect(font.getGsubData(), same(GsubData.noDataFound));

    font.enabledGsubFeatures.add('liga');
    expect(font.getUnicodeCmapLookup(), isNotNull);
  });

  test('mapCodePointsToGlyphIds aplica UVS no fluxo do TrueTypeFont', () {
    final font = TrueTypeFont(glyphCount: 1024);
    final cmapTable = _buildUnicodeCmapTableWithVariation(font);
    font.addTable(cmapTable);

    final glyphs = font.mapCodePointsToGlyphIds(
      <int>[0x1F600, 0xFE0F, 0x1F601, 0xFE0F, 0x1F601],
    );

    expect(glyphs, orderedEquals(<int>[400, 520, 401]));
  });

  test('metrics, geometry, and GSUB helpers', () {
    final header = HeaderTable()
      ..unitsPerEm = 2048
      ..xMin = -50
      ..yMin = -120
      ..xMax = 1100
      ..yMax = 900;

    final stubPath = GlyphPath()..moveTo(0, 0);
    final glyph = _StubGlyphData(stubPath);
    final glyphTable = _StubGlyphTable(<int, GlyphData?>{1: glyph});

    final font = _TestTrueTypeFont(glyphMap: <String, int>{'A': 1})
      ..advanceWidth = 600
      ..header = header
      ..glyphTable = glyphTable;

    expect(font.isEnableGsub, isTrue);
    font.setEnableGsub(false);
    expect(font.isEnableGsub, isFalse);
    font.setEnableGsub(true);

    expect(font.getWidth('A'), 600);
    expect(font.getWidth('missing'), 0);

    final bbox = font.getFontBBox();
    expect(bbox, isNotNull);
    final scale = 1000 / 2048;
    expect(bbox!.lowerLeftX, closeTo(-50 * scale, 1e-9));
    expect(bbox.lowerLeftY, closeTo(-120 * scale, 1e-9));
    expect(bbox.upperRightX, closeTo(1100 * scale, 1e-9));
    expect(bbox.upperRightY, closeTo(900 * scale, 1e-9));

    expect(
        font.getFontMatrix(), equals(<double>[1 / 2048, 0, 0, 1 / 2048, 0, 0]));

    final resolved = font.getPath('A');
    expect(identical(resolved, stubPath), isTrue);
    expect(font.getPath('missing').isEmpty, isTrue);

    font.enableGsubFeature('liga');
    font.enableGsubFeature('liga');
    font.enableVerticalSubstitutions();
    font.enableVerticalSubstitutions();
    expect(
        font.enabledGsubFeatures.where((value) => value == 'liga').length, 1);
    expect(
        font.enabledGsubFeatures.where((value) => value == 'vrt2').length, 1);
    expect(
        font.enabledGsubFeatures.where((value) => value == 'vert').length, 1);

    font.disableGsubFeature('liga');
    expect(font.enabledGsubFeatures, isNot(contains('liga')));

    font.postScriptName = 'StubPS';
    expect(font.toString(), 'StubPS');
    font.postScriptName = null;
    expect(font.toString(), '(null)');
  });

  test('resolveJstfLookupControl expõe priorizações de lookup', () {
    final script = JstfScript(
      extenderGlyphs: const <int>[],
      defaultLangSys: JstfLangSys(
        <JstfPriority>[
          JstfPriority(
            gsubShrinkageEnable: JstfModList(<int>[0x15]),
          ),
        ],
      ),
      langSysRecords: const <String, JstfLangSys>{},
    );

    final jstf = _StubJstfTable(<String, JstfScript>{'latn': script});
    final font = _JstfAwareTrueTypeFont(jstf);
    final control = font.resolveJstfLookupControl(
      scriptTag: 'latn',
      mode: JstfAdjustmentMode.shrink,
    );

    expect(control.enabledGsubLookups, contains(0x15));
    expect(control.disabledGsubLookups, isEmpty);
  });
}

CmapTable _buildFormat0CmapTable(TrueTypeFont font,
    {required int codePoint, required int glyphId}) {
  final builder = BytesBuilder()
    ..add(_ushort(0)) // version
    ..add(_ushort(1)) // number of tables
    ..add(_ushort(CmapTable.platformWindows))
    ..add(_ushort(CmapTable.encodingWinUnicodeBmp))
    ..add(_uint(12)); // offset to subtable

  final glyphArray = List<int>.filled(256, 0);
  if (codePoint >= 0 && codePoint < glyphArray.length) {
    glyphArray[codePoint] = glyphId & 0xff;
  }

  builder
    ..add(_ushort(0)) // format 0
    ..add(_ushort(262)) // length
    ..add(_ushort(0)) // language
    ..add(glyphArray);

  final data = Uint8List.fromList(builder.takeBytes());
  final table = CmapTable()
    ..setTag(CmapTable.tableTag)
    ..setOffset(0)
    ..setLength(data.length);
  table.read(font, RandomAccessReadDataStream.fromData(data));
  return table;
}

PostScriptTable _buildFormat1PostTable(TrueTypeFont font) {
  final data = Uint8List.fromList(<int>[
    ..._fixed32(1, 0),
    ..._fixed32(0, 0),
    ..._short(0),
    ..._short(0),
    ..._uint(0),
    ..._uint(0),
    ..._uint(0),
    ..._uint(0),
    ..._uint(0),
  ]);

  final table = PostScriptTable()
    ..setTag(PostScriptTable.tableTag)
    ..setOffset(0)
    ..setLength(data.length);
  table.read(font, RandomAccessReadDataStream.fromData(data));
  return table;
}

List<int> _ushort(int value) => <int>[(value >> 8) & 0xff, value & 0xff];

List<int> _short(int value) {
  final encoded = value & 0xffff;
  return <int>[(encoded >> 8) & 0xff, encoded & 0xff];
}

List<int> _uint(int value) => <int>[
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];

List<int> _fixed32(int integer, int fractional) {
  final value = (integer << 16) | (fractional & 0xffff);
  return <int>[
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];
}

CmapTable _buildUnicodeCmapTableWithVariation(TrueTypeFont font) {
  const numTables = 2;
  final format12 = _format12SubtableBytes();
  final format14 = _format14SubtableBytes();
  final headerSize = 4 + (numTables * 8);

  final variationOffset = headerSize + format12.length;

  final builder = BytesBuilder()
    ..add(_ushort(0))
    ..add(_ushort(numTables))
    ..add(_ushort(CmapTable.platformUnicode))
    ..add(_ushort(CmapTable.encodingUnicode20Full))
    ..add(_uint(headerSize))
    ..add(_ushort(CmapTable.platformUnicode))
    ..add(_ushort(5))
    ..add(_uint(variationOffset))
    ..add(format12)
    ..add(format14);

  final data = Uint8List.fromList(builder.takeBytes());
  final table = CmapTable()
    ..setTag(CmapTable.tableTag)
    ..setOffset(0)
    ..setLength(data.length);
  table.read(font, RandomAccessReadDataStream.fromData(data));
  return table;
}

List<int> _format12SubtableBytes() {
  final data = <int>[];
  data
    ..addAll(_ushort(12))
    ..addAll(_ushort(0))
    ..addAll(_uint(0x0000001C))
    ..addAll(_uint(0))
    ..addAll(_uint(1))
    ..addAll(_uint(0x1F600))
    ..addAll(_uint(0x1F601))
    ..addAll(_uint(400));
  return data;
}

List<int> _format14SubtableBytes() {
  final data = <int>[];
  data
    ..addAll(_ushort(14))
    ..addAll(_ushort(0))
    ..addAll(_uint(0))
    ..addAll(_uint(1));

  data.addAll(_u24(0x00FE0F));
  final defaultOffsetIndex = data.length;
  data.addAll(_uint(0));
  final nonDefaultOffsetIndex = data.length;
  data.addAll(_uint(0));

  data.add(0);

  final defaultOffset = data.length;
  data
    ..addAll(_uint(1))
    ..addAll(_u24(0x001F600))
    ..add(0);

  while (data.length % 4 != 0) {
    data.add(0);
  }

  final nonDefaultOffset = data.length;
  data
    ..addAll(_uint(1))
    ..addAll(_u24(0x001F601))
    ..addAll(_ushort(520));

  final length = data.length;
  _writeU32(data, 4, length);
  _writeU32(data, defaultOffsetIndex, defaultOffset);
  _writeU32(data, nonDefaultOffsetIndex, nonDefaultOffset);

  return data;
}

List<int> _u24(int value) => <int>[
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];

void _writeU32(List<int> buffer, int offset, int value) {
  buffer[offset] = (value >> 24) & 0xff;
  buffer[offset + 1] = (value >> 16) & 0xff;
  buffer[offset + 2] = (value >> 8) & 0xff;
  buffer[offset + 3] = value & 0xff;
}

class _StubGlyphData extends GlyphData {
  _StubGlyphData(this._path);

  final GlyphPath _path;

  @override
  GlyphPath getPath() => _path;
}

class _StubGlyphTable extends GlyphTable {
  _StubGlyphTable(this._glyphs);

  final Map<int, GlyphData?> _glyphs;

  @override
  GlyphData? getGlyph(int gid, [int level = 0]) => _glyphs[gid];
}

class _TestTrueTypeFont extends TrueTypeFont {
  _TestTrueTypeFont({required this.glyphMap}) : super(glyphCount: 10);

  final Map<String, int> glyphMap;
  late int advanceWidth;
  HeaderTable? header;
  GlyphTable? glyphTable;
  String? postScriptName;

  @override
  int nameToGid(String name) => glyphMap[name] ?? 0;

  @override
  int getAdvanceWidth(int gid) => advanceWidth;

  @override
  HeaderTable? getHeaderTable() => header;

  @override
  GlyphTable? getGlyphTable() => glyphTable;

  @override
  String? getName() => postScriptName;
}

class _StubJstfTable extends OtlTable {
  _StubJstfTable(this._scripts);

  final Map<String, JstfScript> _scripts;

  @override
  Map<String, JstfScript> get scripts => _scripts;

  @override
  bool get hasScripts => _scripts.isNotEmpty;

  @override
  JstfScript? getScript(String scriptTag) => _scripts[scriptTag];
}

class _JstfAwareTrueTypeFont extends TrueTypeFont {
  _JstfAwareTrueTypeFont(this._jstf) : super(glyphCount: 0);

  final OtlTable _jstf;

  @override
  OtlTable? getJstfTable() => _jstf;
}
