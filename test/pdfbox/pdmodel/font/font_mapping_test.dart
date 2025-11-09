import 'package:pdfbox_dart/src/fontbox/cff/char_string_path.dart';
import 'package:pdfbox_dart/src/fontbox/font_box_font.dart';
import 'package:pdfbox_dart/src/fontbox/util/bounding_box.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/font_mapping.dart';
import 'package:test/test.dart';

class _DummyFont implements FontBoxFont {
  @override
  BoundingBox getFontBBox() =>
      BoundingBox.fromValues(0, 0, 1000, 1000);

  @override
  List<num> getFontMatrix() => const <num>[1, 0, 0, 1, 0, 0];

  @override
  String getName() => 'DummyFont';

  @override
  bool hasGlyph(String name) => name == 'a';

  @override
  CharStringPath getPath(String name) {
    final path = CharStringPath();
    path.moveTo(0, 0);
    path.lineTo(100, 0);
    path.lineTo(100, 100);
    path.closePath();
    return path;
  }

  @override
  double getWidth(String name) => name == 'a' ? 500 : 0;
}

void main() {
  group('FontMapping', () {
    test('stores font reference and fallback flag', () {
      final font = _DummyFont();
      final mapping = FontMapping<_DummyFont>(font);

      expect(mapping.font, same(font));
      expect(mapping.isFallback, isFalse);
      expect(mapping.hasFont, isTrue);
    });

    test('asserts when fallback flag missing for null font', () {
      expect(
        () => FontMapping<_DummyFont>(null),
        throwsA(isA<AssertionError>()),
      );
    });

    test('allows fallback-only mapping', () {
      final mapping = FontMapping<_DummyFont>(null, isFallback: true);
      expect(mapping.font, isNull);
      expect(mapping.hasFont, isFalse);
      expect(mapping.isFallback, isTrue);
    });
  });
}
