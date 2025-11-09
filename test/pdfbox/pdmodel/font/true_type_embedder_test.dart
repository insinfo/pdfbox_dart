import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/ttf/cmap_lookup.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/glyph_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/header_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/horizontal_header_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/horizontal_metrics_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/index_to_location_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/maximum_profile_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/name_record.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/naming_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/os2_windows_metrics_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/post_script_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/ttf_table.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/true_type_embedder.dart';
import 'package:test/test.dart';

class _TestCmapLookup implements CMapLookup {
  _TestCmapLookup(this._forwardMap) {
    _reverseMap = <int, List<int>>{};
    _forwardMap.forEach((codePoint, gid) {
      _reverseMap.putIfAbsent(gid, () => <int>[]).add(codePoint);
    });
  }

  final Map<int, int> _forwardMap;
  late final Map<int, List<int>> _reverseMap;

  @override
  int getGlyphId(int codePoint, [int? variationSelector]) =>
      _forwardMap[codePoint] ?? 0;

  @override
  List<int>? getCharCodes(int glyphId) => _reverseMap[glyphId];
}

class _TestGlyphTable extends GlyphTable {
  _TestGlyphTable(int length, int offset) {
    setTag(GlyphTable.tableTag);
    setLength(length);
    setOffset(offset);
    setInitialized(true);
  }
}

class _TestLocaTable extends IndexToLocationTable {
  _TestLocaTable(this._offsets) {
    setTag(IndexToLocationTable.tableTag);
    setInitialized(true);
  }

  final List<int> _offsets;

  @override
  List<int> get offsets => List<int>.unmodifiable(_offsets);
}

class _TestHorizontalMetricsTable extends HorizontalMetricsTable {
  _TestHorizontalMetricsTable(int length) {
    setTag(HorizontalMetricsTable.tableTag);
    setLength(length);
    setOffset(0);
    setInitialized(true);
  }
}

class _TestNamingTable extends NamingTable {
  _TestNamingTable(this._records, this._postScriptName) {
    setTag(NamingTable.tableTag);
    setInitialized(true);
  }

  final List<NameRecord> _records;
  final String _postScriptName;

  @override
  List<NameRecord> getNameRecords() => List<NameRecord>.unmodifiable(_records);

  @override
  String? getPostScriptName() => _postScriptName;

  @override
  String? getFontFamily() => 'TestFamily';

  @override
  String? getFontSubFamily() => 'Regular';
}

class _TestPostScriptTable extends PostScriptTable {
  _TestPostScriptTable(this._names) {
    setTag(PostScriptTable.tableTag);
    setInitialized(true);
  }

  final List<String> _names;

  @override
  List<String>? get glyphNames => List<String>.from(_names);

  @override
  String? getName(int gid) => (gid >= 0 && gid < _names.length) ? _names[gid] : null;

  @override
  double get italicAngle => 0;

  @override
  int get underlinePosition => -50;

  @override
  int get underlineThickness => 50;

  @override
  int get isFixedPitch => 0;

  @override
  int get minMemType42 => 0;

  @override
  int get maxMemType42 => 0;

  @override
  int get minMemType1 => 0;

  @override
  int get maxMemType1 => 0;
}

class _TestOs2Table extends Os2WindowsMetricsTable {
  _TestOs2Table() {
    setTag(Os2WindowsMetricsTable.tableTag);
    setInitialized(true);
  }

  @override
  int get version => 0;

  @override
  int get averageCharWidth => 500;

  @override
  int get weightClass => 400;

  @override
  int get widthClass => Os2WindowsMetricsTable.widthClassMedium;

  @override
  int get fsType => 0;

  @override
  int get subscriptXSize => 650;

  @override
  int get subscriptYSize => 600;

  @override
  int get subscriptXOffset => 0;

  @override
  int get subscriptYOffset => 75;

  @override
  int get superscriptXSize => 650;

  @override
  int get superscriptYSize => 600;

  @override
  int get superscriptXOffset => 0;

  @override
  int get superscriptYOffset => 350;

  @override
  int get strikeoutSize => 50;

  @override
  int get strikeoutPosition => 300;

  @override
  int get familyClass => Os2WindowsMetricsTable.familyClassSansSerif;

  @override
  Uint8List get panose => Uint8List(10);

  @override
  String get achVendId => 'TEST';

  @override
  int get fsSelection => 0;

  @override
  int get typoAscender => 750;

  @override
  int get typoDescender => -250;

  @override
  int get typoLineGap => 0;

  @override
  int get winAscent => 800;

  @override
  int get winDescent => 200;
}

class _RawDataTable extends TtfTable {
  _RawDataTable(String tag, int length) {
    setTag(tag);
    setLength(length);
    setOffset(0);
    setInitialized(true);
  }
}

class _TestTrueTypeFont extends TrueTypeFont {
  _TestTrueTypeFont({
    required int glyphCount,
    required CMapLookup cmapLookup,
    required HeaderTable header,
    required HorizontalHeaderTable hhea,
    required MaximumProfileTable maxp,
    required _TestOs2Table os2,
    required _TestPostScriptTable post,
    required _TestNamingTable naming,
    required _TestLocaTable loca,
    required _TestGlyphTable glyph,
    required _TestHorizontalMetricsTable hmtx,
    required Map<String, Uint8List> tableData,
  })  : _cmapLookup = cmapLookup,
        _header = header,
        _hhea = hhea,
        _maxp = maxp,
        _os2 = os2,
        _post = post,
        _naming = naming,
        _loca = loca,
        _glyph = glyph,
        _hmtx = hmtx,
        _tableData = tableData,
        super(glyphCount: glyphCount) {
    addTable(glyph);
    addTable(loca);
    addTable(hmtx);
    addTable(header);
    addTable(hhea);
    addTable(maxp);
    addTable(os2);
    addTable(post);
    addTable(naming);
    for (final entry in tableData.entries) {
      if (!_registeredTags.contains(entry.key)) {
        addTable(_RawDataTable(entry.key, entry.value.length));
      }
    }
  }

  static const Set<String> _registeredTags = <String>{
    GlyphTable.tableTag,
    IndexToLocationTable.tableTag,
    HorizontalMetricsTable.tableTag,
    HeaderTable.tableTag,
    HorizontalHeaderTable.tableTag,
    MaximumProfileTable.tableTag,
    Os2WindowsMetricsTable.tableTag,
    PostScriptTable.tableTag,
    NamingTable.tableTag,
  };

  final CMapLookup _cmapLookup;
  final HeaderTable _header;
  final HorizontalHeaderTable _hhea;
  final MaximumProfileTable _maxp;
  final _TestOs2Table _os2;
  final _TestPostScriptTable _post;
  final _TestNamingTable _naming;
  final _TestLocaTable _loca;
  final _TestGlyphTable _glyph;
  final _TestHorizontalMetricsTable _hmtx;
  final Map<String, Uint8List> _tableData;

  @override
  CMapLookup? getUnicodeCmapLookup({bool isStrict = true}) => _cmapLookup;

  @override
  HeaderTable? getHeaderTable() => _header;

  @override
  HorizontalHeaderTable? getHorizontalHeaderTable() => _hhea;

  @override
  MaximumProfileTable? getMaximumProfileTable() => _maxp;

  @override
  HorizontalMetricsTable? getHorizontalMetricsTable() => _hmtx;

  @override
  IndexToLocationTable? getIndexToLocationTable() => _loca;

  @override
  GlyphTable? getGlyphTable() => _glyph;

  @override
  NamingTable? getNamingTable() => _naming;

  @override
  Os2WindowsMetricsTable? getOs2WindowsMetricsTable() => _os2;

  @override
  PostScriptTable? getPostScriptTable() => _post;

  @override
  Uint8List getTableBytes(TtfTable table) {
    final data = _tableData[table.tag];
    if (data == null) {
      throw StateError('Missing table data for ${table.tag}');
    }
    return Uint8List.fromList(data);
  }

  @override
  Uint8List getTableNBytes(TtfTable table, int limit) {
    final data = getTableBytes(table);
    final safeLength = limit < data.length ? limit : data.length;
    return data.sublist(0, safeLength);
  }
}

_TestTrueTypeFont _buildTestFont() {
  final header = HeaderTable()
    ..setTag(HeaderTable.tableTag)
    ..setLength(54)
    ..setOffset(0)
    ..setInitialized(true)
    ..version = 1.0
    ..fontRevision = 1.0
    ..magicNumber = 0x5F0F3CF5
    ..flags = 5
    ..unitsPerEm = 1000
    ..created = DateTime.utc(2020, 1, 1)
    ..modified = DateTime.utc(2020, 1, 1)
    ..xMin = 0
    ..yMin = 0
    ..xMax = 600
    ..yMax = 800
    ..macStyle = 0
    ..lowestRecPpem = 8
    ..fontDirectionHint = 2
    ..glyphDataFormat = 0;

  final hhea = HorizontalHeaderTable()
    ..setTag(HorizontalHeaderTable.tableTag)
    ..setLength(36)
    ..setOffset(0)
    ..setInitialized(true)
    ..version = 1.0
    ..ascender = 800
    ..descender = -200
    ..lineGap = 0
    ..advanceWidthMax = 600
    ..minLeftSideBearing = 0
    ..minRightSideBearing = 0
    ..xMaxExtent = 600
    ..caretSlopeRise = 1
    ..caretSlopeRun = 0
    ..metricDataFormat = 0
    ..numberOfHMetrics = 3;

  final maxp = MaximumProfileTable()
    ..setTag(MaximumProfileTable.tableTag)
    ..setLength(32)
    ..setOffset(0)
    ..setInitialized(true)
    ..version = 1.0
    ..numGlyphs = 4
    ..maxPoints = 10
    ..maxContours = 1
    ..maxCompositePoints = 0
    ..maxCompositeContours = 1
    ..maxZones = 2
    ..maxTwilightPoints = 0
    ..maxStorage = 0
    ..maxFunctionDefs = 0
    ..maxInstructionDefs = 0
    ..maxStackElements = 0
    ..maxSizeOfInstructions = 0
    ..maxComponentElements = 2
    ..maxComponentDepth = 2;

  final os2 = _TestOs2Table();
  final post = _TestPostScriptTable(<String>['.notdef', 'A', 'B', 'C']);

  final namingRecords = <NameRecord>[
    NameRecord()
      ..platformId = NameRecord.platformWindows
      ..platformEncodingId = NameRecord.encodingWindowsUnicodeBmp
      ..languageId = NameRecord.languageWindowsEnUs
      ..nameId = NameRecord.namePostScriptName
      ..string = 'TestPS',
    NameRecord()
      ..platformId = NameRecord.platformWindows
      ..platformEncodingId = NameRecord.encodingWindowsUnicodeBmp
      ..languageId = NameRecord.languageWindowsEnUs
      ..nameId = NameRecord.nameFontFamilyName
      ..string = 'TestFamily',
    NameRecord()
      ..platformId = NameRecord.platformWindows
      ..platformEncodingId = NameRecord.encodingWindowsUnicodeBmp
      ..languageId = NameRecord.languageWindowsEnUs
      ..nameId = NameRecord.nameFontSubFamilyName
      ..string = 'Regular',
  ];
  final naming = _TestNamingTable(namingRecords, 'TestPS');

  final glyfData = Uint8List.fromList(<int>[
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
    0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0,
    0x00, 0x00,
    0x00, 0x02,
    0x00, 0x00,
    0x00, 0x00,
  ]);
  final glyphTable = _TestGlyphTable(glyfData.length, 0);
  final loca = _TestLocaTable(<int>[0, 10, 20, 30, 46]);

  final hmtxBytes = Uint8List.fromList(<int>[
    0x01, 0xF4, 0, 0,
    0x02, 0x58, 0, 0,
    0x02, 0x58, 0, 0,
    0x00, 0x00,
  ]);
  final hmtx = _TestHorizontalMetricsTable(hmtxBytes.length);

  final tableData = <String, Uint8List>{
    'glyf': glyfData,
    'hmtx': hmtxBytes,
    'cvt ': Uint8List(0),
    'prep': Uint8List(0),
    'fpgm': Uint8List(0),
    'gasp': Uint8List(0),
  };

  final cmapLookup = _TestCmapLookup(<int, int>{
    0x41: 1,
    0x42: 2,
    0x43: 3,
  });

  return _TestTrueTypeFont(
    glyphCount: 4,
    cmapLookup: cmapLookup,
    header: header,
    hhea: hhea,
    maxp: maxp,
    os2: os2,
    post: post,
    naming: naming,
    loca: loca,
    glyph: glyphTable,
    hmtx: hmtx,
    tableData: tableData,
  );
}

Uint8List _readTable(Uint8List font, String tag) {
  final view = ByteData.sublistView(font);
  final tableCount = view.getUint16(4, Endian.big);
  var offset = 12;
  for (var i = 0; i < tableCount; i++) {
    final tableTag = String.fromCharCodes(font.sublist(offset, offset + 4));
    final tableOffset = view.getUint32(offset + 8, Endian.big);
    final length = view.getUint32(offset + 12, Endian.big);
    if (tableTag == tag) {
      return font.sublist(tableOffset, tableOffset + length);
    }
    offset += 16;
  }
  throw StateError('Table $tag not found');
}

String _decodeUtf16be(Uint8List bytes) {
  if (bytes.isEmpty) {
    return '';
  }
  final view = ByteData.sublistView(bytes);
  final codeUnits = List<int>.generate(bytes.length ~/ 2, (index) {
    return view.getUint16(index * 2, Endian.big);
  });
  return String.fromCharCodes(codeUnits);
}

void main() {
  test('composite glyph dependencies are included and rewritten', () {
    final font = _buildTestFont();
    final embedder = TrueTypeEmbedder(font);
    embedder.addToSubset(0x43);

    final result = embedder.subset();

    expect(result.tag, equals('AAAAAF+'));
    expect(result.newToOldGlyphId, equals(<int, int>{0: 0, 1: 2, 2: 3}));

    final locaTable = _readTable(result.fontData, 'loca');
    final locaView = ByteData.sublistView(locaTable);
    expect(locaView.getUint32(0, Endian.big), equals(0));
    expect(locaView.getUint32(4, Endian.big), equals(12));
    expect(locaView.getUint32(8, Endian.big), equals(24));
    expect(locaView.getUint32(12, Endian.big), equals(40));

    final glyfTable = _readTable(result.fontData, 'glyf');
    final glyphOffset = 24;
    final glyfView = ByteData.sublistView(glyfTable);
    final componentFlags = glyfView.getUint16(glyphOffset + 10, Endian.big);
    final componentGid = glyfView.getUint16(glyphOffset + 12, Endian.big);
    expect(componentFlags, equals(0));
    expect(componentGid, equals(1));
  });

  test('subsets are deterministic and prefix applied to PostScript name', () {
    final embedderA = TrueTypeEmbedder(_buildTestFont());
    embedderA.addToSubset(0x43);
    final resultA = embedderA.subset();

    final embedderB = TrueTypeEmbedder(_buildTestFont());
    embedderB.addToSubset(0x43);
    final resultB = embedderB.subset();

    expect(resultB.tag, equals(resultA.tag));
    expect(resultB.fontData, equals(resultA.fontData));

    final nameTable = _readTable(resultA.fontData, 'name');
    final nameView = ByteData.sublistView(nameTable);
    final count = nameView.getUint16(2, Endian.big);
    final storageOffset = nameView.getUint16(4, Endian.big);
    String? postScript;
    for (var i = 0; i < count; i++) {
      final recordOffset = 6 + i * 12;
      final nameId = nameView.getUint16(recordOffset + 6, Endian.big);
      if (nameId == NameRecord.namePostScriptName) {
        final length = nameView.getUint16(recordOffset + 8, Endian.big);
        final offset = nameView.getUint16(recordOffset + 10, Endian.big);
        final start = storageOffset + offset;
        final slice = nameTable.sublist(start, start + length);
        postScript = _decodeUtf16be(Uint8List.fromList(slice));
        break;
      }
    }
    expect(postScript, equals('AAAAAF+TestPS'));
  });
}
