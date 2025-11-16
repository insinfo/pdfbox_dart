import 'package:test/test.dart';

import 'package:pdfbox_dart/src/jj2000/j2k/not_implemented_error.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/wavelet/wt_decomp_spec.dart';

void main() {
  group('WTDecompSpec', () {
    test('defaults to dyadic decomposition', () {
      final spec = WTDecompSpec(2, WTDecompSpec.wtDecompDyadic, 5);
      expect(spec.getMainDefDecompType(), WTDecompSpec.wtDecompDyadic);
      expect(spec.getMainDefLevels(), 5);
      expect(spec.getDecSpecType(0), WTDecompSpec.decSpecMainDef);
      expect(spec.getDecompType(1), WTDecompSpec.wtDecompDyadic);
      expect(spec.getLevels(1), 5);
    });

    test('component override is not implemented', () {
      final spec = WTDecompSpec(1, WTDecompSpec.wtDecompDyadic, 3);
      expect(
        () => spec.setMainCompDefDecompType(0, WTDecompSpec.wtDecompPacket, 2),
        throwsA(isA<NotImplementedError>()),
      );
    });

    test('copy preserves configuration', () {
      final spec = WTDecompSpec(1, WTDecompSpec.wtDecompDyadic, 4);
      final copy = spec.getCopy();
      expect(copy.getMainDefDecompType(), spec.getMainDefDecompType());
      expect(copy.getMainDefLevels(), spec.getMainDefLevels());
      expect(copy.getDecSpecType(0), spec.getDecSpecType(0));
    });
  });
}
