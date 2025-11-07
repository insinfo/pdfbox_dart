import 'package:pdfbox_dart/src/fontbox/ttf/gsub/gsub_worker_for_gujarati.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/language.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('GsubWorkerForGujarati', () {
    test('repositions reph and before-half glyphs', () {
      final lookup = FakeCMapLookup(const <int, int>{
        0x0AB0: 110,
        0x0ACD: 120,
        0x0ABE: 130,
        0x0AC0: 140,
        0x0ABF: 150,
      });

      final worker = GsubWorkerForGujarati(
        lookup,
        buildGsubData(Language.gujarati, 'gujr'),
      );

      final result = worker.applyTransforms(<int>[110, 120, 999, 130, 150]);

      expect(result, <int>[999, 130, 110, 150, 120]);
      expect(() => result.add(1), throwsUnsupportedError);
    });
  });
}
