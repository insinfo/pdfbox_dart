import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/cos_array_list.dart';
import 'package:test/test.dart';

void main() {
  test('maintains dictionary synchronisation', () {
    final dictionary = COSDictionary();
    final key = COSName('Test');
    final list = COSArrayList<String>.deferred(dictionary, key);

    list.add('Alpha');
    expect(list.length, 1);

    final cosArray = dictionary.getCOSArray(key);
    expect(cosArray, isNotNull);
    expect(cosArray!.length, 1);
    final first = cosArray.getObject(0);
    expect(first, isA<COSString>());
    expect((first as COSString).string, 'Alpha');

    list.add('Beta');
    expect(list.length, 2);
    expect(dictionary.getCOSArray(key)!.length, 2);

    list.remove('Alpha');
    expect(list.length, 1);
    expect(dictionary.getCOSArray(key)!.length, 1);
    final remaining = dictionary.getCOSArray(key)!.getObject(0) as COSString;
    expect(remaining.string, 'Beta');
  });

  test('converterToCOSArray converts primitives', () {
    final array = COSArrayList.converterToCOSArray(<dynamic>[
      'Text',
      3,
      4.5,
      true,
      COSArray(),
    ]);
    expect(array, isA<COSArray>());
    expect(array!.length, 5);
  });
}
