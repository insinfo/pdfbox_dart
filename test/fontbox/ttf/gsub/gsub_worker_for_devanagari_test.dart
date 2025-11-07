import 'package:pdfbox_dart/src/fontbox/ttf/gsub/gsub_worker_for_devanagari.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/language.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('GsubWorkerForDevanagari', () {
    test('adjusts reph sequences before GSUB feature processing', () {
      final lookup = FakeCMapLookup(const <int, int>{
        0x0930: 210,
        0x094D: 220,
        0x093E: 230,
        0x0940: 240,
        0x093F: 250,
      });

      final worker = GsubWorkerForDevanagari(
        lookup,
        buildGsubData(Language.devanagari, 'deva'),
      );

      final result = worker.applyTransforms(<int>[210, 220, 999]);

      expect(result, <int>[999, 210, 220]);
      expect(() => result.add(5), throwsUnsupportedError);
    });
  });
}
