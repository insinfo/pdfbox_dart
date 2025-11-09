import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('CFFCIDFont', () {
    test('exposes FontBoxFont contract for CID selectors', () {
      final font = createSimpleCidFont();

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
      expect(font.hasCID(1), isTrue);
      expect(font.hasCID(9999), isFalse);

      expect(
          font.getPathForCID(1).commands.length, equals(path.commands.length));
      expect(font.getWidthForCID(1), closeTo(width, 1e-6));

      expect(() => font.getPath('bad'), throwsArgumentError);
      expect(() => font.getWidth(r'\xyz'), throwsArgumentError);
    });

    test('caches charstrings and falls back to .notdef', () {
      final font = createSimpleCidFont();

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
