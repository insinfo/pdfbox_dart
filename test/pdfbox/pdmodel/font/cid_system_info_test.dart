import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/cid_system_info.dart';
import 'package:test/test.dart';

void main() {
  group('CidSystemInfo', () {
    test('stores registry ordering and supplement', () {
      const info = CidSystemInfo(
        registry: 'Adobe',
        ordering: 'Japan1',
        supplement: 6,
      );

      expect(info.registry, equals('Adobe'));
      expect(info.ordering, equals('Japan1'));
      expect(info.supplement, equals(6));
      expect(info.toString(), equals('Adobe-Japan1-6'));
    });
  });
}
