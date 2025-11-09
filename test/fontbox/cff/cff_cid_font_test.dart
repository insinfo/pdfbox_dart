import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/cff/cff_charset.dart';
import 'package:pdfbox_dart/src/fontbox/cff/cff_font.dart';
import 'package:test/test.dart';

class _ConstantFdSelect implements CFFFDSelect {
  const _ConstantFdSelect(this._index);

  final int _index;

  @override
  int getFDIndex(int gid) => _index;
}

void main() {
  group('CFFCIDFont', () {
    test('exposes FontBoxFont contract for CID selectors', () {
      final font = _createCidFont();

      expect(font.getName(), equals('CIDFont'));
      expect(
        font.getFontMatrix(),
        orderedEquals(<num>[0.001, 0, 0, 0.001, 0, 0]),
      );
      final bbox = font.getFontBBox();
      expect(bbox.lowerLeftX, closeTo(-50, 1e-6));
      expect(bbox.lowerLeftY, closeTo(-250, 1e-6));
      expect(bbox.upperRightX, closeTo(1200, 1e-6));
      expect(bbox.upperRightY, closeTo(950, 1e-6));

      final path = font.getPath(r'\0001');
      expect(path.commands, isNotEmpty);

  final width = font.getWidth(r'\0001');
  expect(width, closeTo(600, 1e-6));

      expect(font.hasGlyph(r'\0001'), isTrue);
      expect(font.hasGlyph(r'\9999'), isFalse);

      expect(
          font.getPathForCID(1).commands.length, equals(path.commands.length));
      expect(font.getWidthForCID(1), closeTo(width, 1e-6));

      expect(() => font.getPath('bad'), throwsArgumentError);
      expect(() => font.getWidth(r'\xyz'), throwsArgumentError);
    });

    test('caches charstrings and falls back to .notdef', () {
      final font = _createCidFont();

      final first = font.getType2CharString(1);
      final second = font.getType2CharString(1);
      expect(identical(first, second), isTrue);

      final fallback = font.getType2CharString(999);
      expect(fallback.cid, equals(999));
      expect(fallback.gidValue, equals(0));
      final fallbackAgain = font.getType2CharString(999);
      expect(identical(fallback, fallbackAgain), isTrue);
      expect(fallback.getPath().commands, isEmpty);
    });
  });
}

CFFCIDFont _createCidFont() {
  final font = CFFCIDFont()
    ..name = 'CIDFont'
    ..charset = EmbeddedCharset(isCidFont: true)
    ..charStrings = <Uint8List>[]
    ..globalSubrIndex = <Uint8List>[]
    ..fontDicts = <Map<String, Object?>>[<String, Object?>{}]
    ..privateDicts = <Map<String, Object?>>[
      <String, Object?>{
        'defaultWidthX': 1000,
        'nominalWidthX': 0,
        'Subrs': <Uint8List>[],
      },
    ]
    ..fdSelect = const _ConstantFdSelect(0);

  font.topDict['FontBBox'] = <num>[-50, -250, 1200, 950];
  font.topDict['FontMatrix'] = <num>[0.001, 0, 0, 0.001, 0, 0];

  final charset = font.charset as EmbeddedCharset;
  charset.addCID(0, 0);
  charset.addCID(1, 1);

  final notdef = Uint8List.fromList(<int>[14]);
  final glyph =
      Uint8List.fromList(<int>[248, 236, 239, 247, 92, 21, 189, 6, 14]);
  font.charStrings = <Uint8List>[notdef, glyph];

  return font;
}
