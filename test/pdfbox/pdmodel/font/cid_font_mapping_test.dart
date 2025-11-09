import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/open_type_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/cid_font_mapping.dart';
import 'package:test/test.dart';

import '../../../fontbox/cff/test_utils.dart';

void main() {
  group('CidFontMapping', () {
    test('captures CID font and TrueType fallback', () {
      final stream = RandomAccessReadDataStream.fromData(Uint8List(0));
      final otf = OpenTypeFont(stream);
      final fallback = createSimpleCidFont();

      final mapping = CidFontMapping(otf, fallback, isFallback: false);

      expect(mapping.font, same(otf));
      expect(mapping.trueTypeFont, same(fallback));
      expect(mapping.isFallback, isFalse);
      expect(mapping.isCidFont, isTrue);
    });

    test('supports fallback-only mapping', () {
      final fallback = createSimpleCidFont();
      final mapping = CidFontMapping(null, fallback, isFallback: true);

      expect(mapping.font, isNull);
      expect(mapping.trueTypeFont, same(fallback));
      expect(mapping.isFallback, isTrue);
      expect(mapping.isCidFont, isFalse);
    });
  });
}
