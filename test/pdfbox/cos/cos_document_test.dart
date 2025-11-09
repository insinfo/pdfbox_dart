import 'package:pdfbox_dart/src/pdfbox/cos/cos_document.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_object.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:test/test.dart';

void main() {
  group('COSDocument', () {
    test('adds and retrieves objects by key', () {
      final document = COSDocument();
      final entry = COSObject(1, 0, COSString('Hello'));
      document.addObject(entry);

      final lookup = document.getObject(entry.key);
      expect(lookup, same(entry));
    });

    test('creates sequential objects', () {
      final document = COSDocument();
      final first = document.createObject();
      final second = document.createObject();

      expect(first.objectNumber, equals(1));
      expect(second.objectNumber, equals(2));
    });

    test('clears resources when closed', () {
      final document = COSDocument();
      document.trailer.setName(COSName('Type'), 'Catalog');
      document.createObject(COSString('Value'));

      document.close();
      expect(document.isClosed, isTrue);
      expect(document.objects, isEmpty);
      expect(document.trailer.isEmpty, isTrue);
    });
  });
}
