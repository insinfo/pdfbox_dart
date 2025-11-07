import 'package:pdfbox_dart/src/fontbox/ttf/gsub/gsub_worker_for_bengali.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/language.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('GsubWorkerForBengali', () {
    test('repositions before-half glyphs and span components', () {
      final lookup = FakeCMapLookup(const <int, int>{
        0x09BF: 100,
        0x09C7: 101,
        0x09C8: 102,
        0x09CB: 200,
        0x09CC: 201,
        0x09BE: 300,
        0x09D7: 301,
      });

      final worker = GsubWorkerForBengali(
        lookup,
        buildGsubData(Language.bengali, 'beng'),
      );

      final result = worker.applyTransforms(<int>[10, 100, 50, 200]);

      expect(result, <int>[100, 10, 101, 50, 300]);
      expect(() => result.add(7), throwsUnsupportedError);
    });
  });
}
