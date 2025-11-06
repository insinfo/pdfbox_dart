import 'package:pdfbox_dart/src/fontbox/ttf/ttf_table.dart';
import 'package:test/test.dart';

void main() {
  group('TtfTable', () {
    test('stores directory metadata', () {
      final table = _TestTable()
        ..setTag('head')
        ..setCheckSum(0xABCDEF01)
        ..setOffset(128)
        ..setLength(256);

      expect(table.tag, 'head');
      expect(table.checkSum, 0xABCDEF01);
      expect(table.offset, 128);
      expect(table.length, 256);
      expect(table.initialized, isFalse);

      table.setInitialized(true);
      expect(table.initialized, isTrue);

      table.setInitialized(false);
      expect(table.initialized, isFalse);
    });
  });
}

class _TestTable extends TtfTable {}
