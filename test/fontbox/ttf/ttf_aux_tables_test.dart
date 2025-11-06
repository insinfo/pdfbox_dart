import 'package:pdfbox_dart/src/fontbox/ttf/digital_signature_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/otl_table.dart';
import 'package:test/test.dart';

void main() {
  group('DigitalSignatureTable', () {
    test('exposes static tag and inherits from TtfTable', () {
      final table = DigitalSignatureTable();
      expect(DigitalSignatureTable.tableTag, 'DSIG');
      expect(table.initialized, isFalse);
    });
  });

  group('OtlTable', () {
    test('exposes static tag and inherits from TtfTable', () {
      final table = OtlTable();
      expect(OtlTable.tableTag, 'JSTF');
      expect(table.initialized, isFalse);
    });
  });
}
