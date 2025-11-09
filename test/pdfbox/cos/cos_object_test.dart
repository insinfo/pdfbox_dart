import 'package:pdfbox_dart/src/pdfbox/cos/cos_null.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_object.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_object_key.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:test/test.dart';

void main() {
  group('COSObject', () {
    test('wraps object using object number and generation', () {
      final obj = COSObject(10, 2, COSString('Value'));
      expect(obj.objectNumber, equals(10));
      expect(obj.generationNumber, equals(2));
      expect(obj.object, isA<COSString>());
    });

    test('replaces null values with COSNull instance', () {
      final obj = COSObject(1, 0, null);
      expect(obj.object, same(COSNull.instance));

      obj.object = null;
      expect(obj.object, same(COSNull.instance));
    });

    test('uses COSObjectKey equality', () {
      final first = COSObject(1, 0);
      final second = COSObject.fromKey(COSObjectKey(1, 0));
      expect(first.key, equals(second.key));
    });
  });
}
