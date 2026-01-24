import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_document.dart';

void main() {
  group('FDFDocument', () {
    test('create initializes catalog and trailer', () {
      final doc = FDFDocument.create();
      final catalog = doc.catalog;

      expect(catalog.cosObject.isNotEmpty, isTrue);
      expect(doc.cosDocument.trailer.isNotEmpty, isTrue);
    });
  });
}
