import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_boolean.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_null.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_object.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/cos_parser.dart';
import 'package:test/test.dart';

COSParser _parserFrom(String content) {
  final bytes = Uint8List.fromList(content.codeUnits);
  return COSParser(RandomAccessReadBuffer.fromBytes(bytes));
}

void main() {
  group('COSParser direct object parsing', () {
    test('parses booleans and null', () {
      final parser = _parserFrom('true false null');

      final trueValue = parser.parseObject() as COSBoolean;
      final falseValue = parser.parseObject() as COSBoolean;
      final nullValue = parser.parseObject() as COSNull;

      expect(trueValue.value, isTrue);
      expect(falseValue.value, isFalse);
      expect(identical(nullValue, COSNull.instance), isTrue);
      expect(parser.parseObject(), isNull);
    });

    test('parses numeric tokens', () {
      final parser = _parserFrom('42 -17 3.14 .5 6e2');

      expect((parser.parseObject() as COSInteger).intValue, 42);
      expect((parser.parseObject() as COSInteger).intValue, -17);
      expect(
          (parser.parseObject() as COSFloat).doubleValue, closeTo(3.14, 1e-6));
      expect(
          (parser.parseObject() as COSFloat).doubleValue, closeTo(0.5, 1e-6));
      expect(
          (parser.parseObject() as COSFloat).doubleValue, closeTo(600.0, 1e-6));
    });

    test('parses names including hex escapes', () {
      final parser = _parserFrom('/Name /A#20B');

      final first = parser.parseObject() as COSName;
      final second = parser.parseObject() as COSName;

      expect(first.name, 'Name');
      expect(second.name, 'A B');
    });

    test('parses literal and hex strings', () {
      final literalParser = _parserFrom('(Line\\nTwo\\053)');
      final literal = literalParser.parseObject() as COSString;
      expect(String.fromCharCodes(literal.bytes), equals('Line\nTwo+'));

      final hexParser = _parserFrom('<48656C6C6F20504644>');
      final hex = hexParser.parseObject() as COSString;
      expect(hex.isHex, isTrue);
      expect(hex.bytes, equals('Hello PFD'.codeUnits));
    });

    test('parses arrays with mixed content', () {
      final parser = _parserFrom('[ /Name (Value) 12 <3031> true ]');
      final array = parser.parseObject() as COSArray;

      expect(array.length, 5);
      expect((array[0] as COSName).name, 'Name');
      expect((array[1] as COSString).string, 'Value');
      expect((array[2] as COSInteger).intValue, 12);
      expect((array[3] as COSString).bytes, equals('01'.codeUnits));
      expect((array[4] as COSBoolean).value, isTrue);
    });

    test('parses dictionaries with nested structures', () {
      final parser = _parserFrom(
          '<< /Type /Example /Count 3 /Names [ (Foo) <426172> ] >>');
      final dict = parser.parseObject() as COSDictionary;

      expect((dict.getCOSName(COSName.type)!).name, 'Example');
      expect(dict.getInt(COSName.get('Count')), 3);

      final names = dict.getCOSArray(COSName.get('Names'))!;
      expect(names.length, 2);
      expect((names[0] as COSString).string, 'Foo');
      expect((names[1] as COSString).bytes, equals('Bar'.codeUnits));
    });

    test('parses empty collections', () {
      final dictParser = _parserFrom('<<>>');
      final arrayParser = _parserFrom('[]');

      expect((dictParser.parseObject() as COSDictionary).isEmpty, isTrue);
      expect((arrayParser.parseObject() as COSArray).isEmpty, isTrue);
    });

    test('parses indirect references', () {
      final parser = _parserFrom('10 0 R 25 2 R 5');

      final first = parser.parseObject() as COSObject;
      final second = parser.parseObject() as COSObject;
      final trailing = parser.parseObject() as COSInteger;

      expect(first.objectNumber, 10);
      expect(first.generationNumber, 0);
      expect(second.objectNumber, 25);
      expect(second.generationNumber, 2);
      expect(trailing.intValue, 5);
    });

    test('does not treat standalone numbers as references', () {
      final parser = _parserFrom('12 34');

      final first = parser.parseObject() as COSInteger;
      final second = parser.parseObject() as COSInteger;

      expect(first.intValue, 12);
      expect(second.intValue, 34);
    });
  });
}
