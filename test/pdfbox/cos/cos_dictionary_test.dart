import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_boolean.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_null.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_object.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:test/test.dart';

void main() {
  group('COSDictionary', () {
    test('stores and retrieves primitive values', () {
      final dict = COSDictionary();
      dict.setInt(COSName('Version'), 2);
      dict.setBoolean(COSName('Compressed'), true);
      dict.setName(COSName('Type'), 'Catalog');

      expect(dict.getInt(COSName('Version')), equals(2));
      expect(dict.getBoolean(COSName('Compressed')), isTrue);
      expect(dict.getCOSName(COSName('Type'))?.name, equals('Catalog'));
    });

    test('handles null removal via setters', () {
      final dict = COSDictionary();
      dict.setInt(COSName('Version'), 2);
      dict.setInt(COSName('Version'), null);

      expect(dict.containsKey(COSName('Version')), isFalse);
    });

    test('dereferences COSObject wrappers', () {
      final dict = COSDictionary();
      final wrapped = COSObject(1, 0, COSString('Hello'));
      dict.setItem(COSName('Message'), wrapped);

      final result = dict.getDictionaryObject(COSName('Message'));
      expect(result, isA<COSString>());
      expect((result as COSString).string, equals('Hello'));
    });

    test('clone performs shallow copies of primitive values', () {
      final dict = COSDictionary();
      final array = COSArray()
        ..add(COSInteger(5))
        ..add(COSBoolean.trueValue);
      dict.setItem(COSName('Array'), array);
      dict.setItem(COSName('Null'), COSNull.instance);

      final copy = dict.clone();
      expect(copy.getCOSArray(COSName('Array'))?.length, equals(2));
      expect(identical(copy.getDictionaryObject(COSName('Null')), COSNull.instance), isTrue);
    });
  });
}
