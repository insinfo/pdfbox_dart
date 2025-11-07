import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/io/ttf_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/font_headers.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_collection.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/naming_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/ttf_parser.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:test/test.dart';

void main() {
  test('processAllFonts uses supplied parser factory', () {
    final collectionData = _buildMinimalTtc();
    final stream = RandomAccessReadDataStream.fromData(collectionData);

    final createdFonts = <_StubFont>[];
    final collection = TrueTypeCollection(
      stream,
      parserFactory: (_) => _RecordingStubParser(createdFonts),
    );

    final observed = <_StubFont>[];
    collection.processAllFonts((font) {
      final stub = font as _StubFont;
      expect(stub.closed, isFalse);
      observed.add(stub);
      stub.close();
    });

    expect(observed, hasLength(1));
    expect(createdFonts, observed);

    collection.close();
  });

  test('getFontByName returns matching font without closing it', () {
    final collectionData = _buildMinimalTtc();
    final stream = RandomAccessReadDataStream.fromData(collectionData);

    final collection = TrueTypeCollection(
      stream,
      parserFactory: (_) => _FixedNameStubParser('StubFont'),
    );

    final font = collection.getFontByName('StubFont');
    expect(font, isNotNull);
    final stub = font as _StubFont;
    expect(stub.closed, isFalse);
    stub.close();

    collection.close();
  });
}

Uint8List _buildMinimalTtc() {
  final tagOffset = 16;
  final header = <int>[]
    ..addAll('ttcf'.codeUnits)
    ..addAll(_fixed32(1, 0))
    ..addAll(_uint32(1))
    ..addAll(_uint32(tagOffset));

  final fontStub = <int>[]
    ..addAll('OTTO'.codeUnits)
    ..addAll(List<int>.filled(16, 0));

  return Uint8List.fromList(<int>[...header, ...fontStub]);
}

List<int> _uint32(int value) => <int>[
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

class _RecordingStubParser extends TtfParser {
  _RecordingStubParser(this._created);

  final List<_StubFont> _created;

  @override
  TrueTypeFont parseDataStream(TtfDataStream dataStream) {
    final font = _StubFont('Recorded-${_created.length}');
    _created.add(font);
    return font;
  }

  @override
  FontHeaders parseTableHeadersFromDataStream(TtfDataStream dataStream) =>
      FontHeaders();
}

class _FixedNameStubParser extends TtfParser {
  _FixedNameStubParser(this._name);

  final String _name;

  @override
  TrueTypeFont parseDataStream(TtfDataStream dataStream) => _StubFont(_name);

  @override
  FontHeaders parseTableHeadersFromDataStream(TtfDataStream dataStream) =>
      FontHeaders();
}

class _StubFont extends TrueTypeFont {
  _StubFont(this._postScriptName) : super(glyphCount: 0);

  final String _postScriptName;
  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }

  @override
  String? getName() => _postScriptName;

  @override
  NamingTable? getNamingTable() => _StubNamingTable(_postScriptName);
}

class _StubNamingTable extends NamingTable {
  _StubNamingTable(this._postScriptName);

  final String _postScriptName;

  @override
  String? getPostScriptName() => _postScriptName;
}
