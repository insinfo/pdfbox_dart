import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/post_script_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/wgl4_names.dart';
import 'package:test/test.dart';

void main() {
  test('format 1 uses Macintosh glyph names', () {
    final data = Uint8List.fromList(<int>[
      ..._fixed32(1, 0),
      ..._fixed32(0, 0),
      ..._short(-100),
      ..._short(50),
      ..._uint(0),
      ..._uint(0),
      ..._uint(0),
      ..._uint(0),
      ..._uint(0),
    ]);

    final table = PostScriptTable()
      ..setTag(PostScriptTable.tableTag)
      ..setLength(data.length);
    table.read(
        TrueTypeFont(glyphCount: 0), RandomAccessReadDataStream.fromData(data));

    final names = table.glyphNames;
    expect(names, isNotNull);
    expect(names!.length, Wgl4Names.numberOfMacGlyphs);
    expect(names[0], '.notdef');
  });

  test('format 2 resolves custom glyph names', () {
    final bytes = BytesBuilder()
      ..add(_fixed32(2, 0))
      ..add(_fixed32(0, 0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_uint(0))
      ..add(_uint(0))
      ..add(_uint(0))
      ..add(_uint(0))
      ..add(_uint(0))
      ..add(_ushort(3)) // numGlyphs
      ..add(_ushort(0)) // index -> .notdef
      ..add(_ushort(200)) // index -> mac glyph name
      ..add(_ushort(Wgl4Names.numberOfMacGlyphs + 0)) // custom name slot 0
      ..add(<int>[3]) // length of custom name
      ..add('foo'.codeUnits);

    final data = Uint8List.fromList(bytes.takeBytes());
    final table = PostScriptTable()
      ..setTag(PostScriptTable.tableTag)
      ..setLength(data.length);
    table.read(
        TrueTypeFont(glyphCount: 3), RandomAccessReadDataStream.fromData(data));

    final names = table.glyphNames;
    expect(names, isNotNull);
    expect(names![0], '.notdef');
    expect(names[1], Wgl4Names.getGlyphName(200));
    expect(names[2], 'foo');
  });

  test('format 2.5 offsets map to Macintosh glyph names', () {
    final glyphCount = 3;
    final bytes = BytesBuilder()
      ..add(_fixed32(2, 0x8000)) // 2.5 in fixed-point is 2.5 -> 0x00028000
      ..add(_fixed32(0, 0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_uint(0))
      ..add(_uint(0))
      ..add(_uint(0))
      ..add(_uint(0))
      ..add(_uint(0));
    // Offsets for 3 glyphs
    bytes.add(<int>[0, 0, 1]);

    final data = Uint8List.fromList(bytes.takeBytes());
    final table = PostScriptTable()
      ..setTag(PostScriptTable.tableTag)
      ..setLength(data.length);
    table.read(TrueTypeFont(glyphCount: glyphCount),
        RandomAccessReadDataStream.fromData(data));

    final names = table.glyphNames;
    expect(names, isNotNull);
    expect(names!.length, glyphCount);
    expect(names[0], Wgl4Names.getGlyphName(1));
    expect(names[2], Wgl4Names.getGlyphName(4));
  });
}

List<int> _fixed32(int integer, int fractional) {
  final value = (integer << 16) | (fractional & 0xffff);
  return <int>[
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];
}

List<int> _short(int value) {
  final encoded = value & 0xffff;
  return <int>[(encoded >> 8) & 0xff, encoded & 0xff];
}

List<int> _ushort(int value) => <int>[(value >> 8) & 0xff, value & 0xff];

List<int> _uint(int value) => <int>[
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
