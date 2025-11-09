import 'package:collection/collection.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/map_backed_script_feature.dart';
import 'package:test/test.dart';

void main() {
  group('MapBackedScriptFeature', () {
    test('exposes substitution sequences and replacements', () {
      final feature = MapBackedScriptFeature('liga', <List<int>, List<int>>{
        <int>[10, 11]: <int>[20],
        <int>[30, 31]: <int>[40, 41],
      });

      final sequences = feature.getAllGlyphIdsForSubstitution().toList();
      expect(sequences, hasLength(2));
      const eq = ListEquality<int>();
      expect(sequences.any((sequence) => eq.equals(sequence, <int>[10, 11])),
          isTrue);
      expect(sequences.any((sequence) => eq.equals(sequence, <int>[30, 31])),
          isTrue);

      expect(feature.canReplaceGlyphs(<int>[10, 11]), isTrue);
      expect(feature.canReplaceGlyphs(<int>[99]), isFalse);

      expect(feature.getReplacementForGlyphs(<int>[30, 31]),
          orderedEquals(<int>[40, 41]));
      expect(() => feature.getReplacementForGlyphs(<int>[1]),
          throwsUnsupportedError);
    });

    test('implements equality by content', () {
      final a = MapBackedScriptFeature('liga', <List<int>, List<int>>{
        <int>[1]: <int>[2],
      });
      final b = MapBackedScriptFeature('liga', <List<int>, List<int>>{
        <int>[1]: <int>[2],
      });
      final c = MapBackedScriptFeature('liga', <List<int>, List<int>>{
        <int>[1]: <int>[3],
      });

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a == c, isFalse);
    });
  });
}
