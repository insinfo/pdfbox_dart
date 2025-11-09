import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/cff/cff_font.dart';
import 'package:pdfbox_dart/src/fontbox/cff/cff_charset.dart';
import 'package:pdfbox_dart/src/fontbox/cff/char_string_path.dart';
import 'package:test/test.dart';

class _ConstantFdSelect implements CFFFDSelect {
  _ConstantFdSelect(this._index);

  final int _index;

  @override
  int getFDIndex(int gid) => _index;
}

void main() {
  test('CID selector helpers resolve charstrings and widths', () {
    final font = CFFCIDFont()
      ..name = 'CIDFont'
      ..charset = EmbeddedCharset(isCidFont: true)
      ..charStrings = <Uint8List>[]
      ..globalSubrIndex = <Uint8List>[]
      ..fontDicts = <Map<String, Object?>>[<String, Object?>{}]
      ..privateDicts = <Map<String, Object?>>[
        <String, Object?>{'defaultWidthX': 1000, 'nominalWidthX': 0},
      ]
      ..fdSelect = _ConstantFdSelect(0);

    final charset = font.charset as EmbeddedCharset;
    charset.addCID(0, 0);
    charset.addCID(1, 1);

    final notdef = Uint8List.fromList(<int>[14]);
    final glyph =
        Uint8List.fromList(<int>[248, 236, 239, 247, 92, 21, 189, 6, 14]);
    font.charStrings = <Uint8List>[notdef, glyph];

    final path = font.getPath(r'\0001');
    expect(path, isA<CharStringPath>());
    expect(path.commands.length, greaterThanOrEqualTo(2));

    final width = font.getWidth(r'\0001');
    expect(width, closeTo(600, 1e-6));

    expect(font.hasGlyph(r'\0001'), isTrue);
    expect(() => font.getPath('not-selector'), throwsArgumentError);
    expect(() => font.getPath(r'\bad'), throwsArgumentError);

    expect(font.getPathForCID(1).commands.length, equals(path.commands.length));
    expect(font.getWidthForCID(1), closeTo(width, 1e-6));
  });

  test('CID charstrings reuse cache across lookups', () {
    final font = CFFCIDFont()
      ..name = 'CIDCache'
      ..charset = EmbeddedCharset(isCidFont: true)
      ..charStrings = <Uint8List>[]
      ..globalSubrIndex = <Uint8List>[]
      ..fontDicts = <Map<String, Object?>>[<String, Object?>{}]
      ..privateDicts = <Map<String, Object?>>[
        <String, Object?>{
          'defaultWidthX': 1000,
          'nominalWidthX': 0,
          'Subrs': <Uint8List>[]
        },
      ]
      ..fdSelect = _ConstantFdSelect(0);

    final charset = font.charset as EmbeddedCharset;
    charset.addCID(0, 0);
    charset.addCID(1, 1);

    final notdef = Uint8List.fromList(<int>[14]);
    final glyph =
        Uint8List.fromList(<int>[248, 236, 239, 247, 92, 21, 189, 6, 14]);
    font.charStrings = <Uint8List>[notdef, glyph];

    final first = font.getType2CharString(1);
    final second = font.getType2CharString(1);
    expect(identical(first, second), isTrue,
        reason: 'Charstrings should be cached per CID');

    final path = first.getPath();
    expect(path.commands, isNotEmpty);

    final fallback = font.getType2CharString(999);
    expect(fallback.gidValue, equals(0),
        reason: 'Unknown CID should map to .notdef');
    expect(fallback.getPath().commands, isEmpty);
  });
}
