import 'package:pdfbox_dart/src/fontbox/ttf/gsub/gsub_worker_for_latin.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/language.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('GsubWorkerForLatin', () {
    test('applies features in documented order', () {
      final worker = GsubWorkerForLatin(
        FakeCMapLookup(const <int, int>{}),
        buildGsubData(
          Language.latin,
          'latn',
          features: <String, Map<List<int>, List<int>>>{
            'ccmp': <List<int>, List<int>>{
              <int>[1, 2]: <int>[10],
            },
            'liga': <List<int>, List<int>>{
              <int>[10, 3]: <int>[42],
            },
            'clig': const <List<int>, List<int>>{},
          },
        ),
      );

      final result = worker.applyTransforms(<int>[1, 2, 3]);

      expect(result, <int>[42]);
      expect(() => result.add(7), throwsUnsupportedError);
    });
  });
}
