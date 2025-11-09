import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:test/test.dart';

void main() {
  group('COSArray', () {
    test('supports add and index access', () {
      final array = COSArray();
      array.add(COSInteger(1));
      array.add(COSName('Two'));

      expect(array.length, equals(2));
      expect(array[0], isA<COSInteger>());
      expect(array[1], isA<COSName>());
    });

    test('iterator yields stored items', () {
      final array = COSArray()
        ..add(COSInteger(1))
        ..add(COSInteger(2))
        ..add(COSInteger(3));

      expect(array.map((value) => (value as COSInteger).intValue), equals(<int>[1, 2, 3]));
    });
  });
}
