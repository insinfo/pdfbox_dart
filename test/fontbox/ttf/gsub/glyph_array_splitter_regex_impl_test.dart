import 'package:pdfbox_dart/src/fontbox/ttf/gsub/glyph_array_splitter_regex_impl.dart';
import 'package:test/test.dart';

void main() {
  group('GlyphArraySplitterRegexImpl', () {
    test('splits glyph ids respecting known substitution sequences', () {
      final splitter = GlyphArraySplitterRegexImpl({
        <int>[1, 2],
        <int>[3, 4]
      });
      final chunks = splitter.split(<int>[1, 2, 5, 3, 4]);

      expect(chunks, <List<int>>[
        <int>[1, 2],
        <int>[5],
        <int>[3, 4]
      ]);
      expect(() => chunks.first[0] = 9, throwsUnsupportedError);
    });
  });
}
