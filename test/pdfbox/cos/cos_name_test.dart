import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:test/test.dart';

void main() {
  group('COSName', () {
    test('caches identical names', () {
      final first = COSName('Type');
      final second = COSName('Type');
      expect(identical(first, second), isTrue);
    });

    test('provides string representation with slash prefix', () {
      expect(COSName('Example').toString(), equals('/Example'));
    });

    test('comparison uses lexical order', () {
      final names = <COSName>[COSName('B'), COSName('A'), COSName('C')];
      names.sort();
      expect(names.map((name) => name.name), equals(<String>['A', 'B', 'C']));
    });
  });
}
