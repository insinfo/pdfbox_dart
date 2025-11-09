import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/base_parser.dart';
import 'package:test/test.dart';

class _TestParser extends BaseParser {
  _TestParser(RandomAccessReadBuffer source) : super(source);

  void skipWhitespace() => skipSpaces();

  String nextToken() => readToken();

  int nextInt() => readInt();

  void skipPostStreamWhitespace() => skipWhiteSpaces();

  bool skipSingleLinebreak() => skipLinebreak();

  String readGenericString() => readString();

  Uint8List readLiteral() => readLiteralString();

  int nextLong() => readLong();

  void expectString(String value, {bool skipSpaces = true}) =>
      readExpectedString(value.codeUnits, skipSurroundingSpaces: skipSpaces);

  void expectChar(String value) => readExpectedChar(value.codeUnitAt(0));
}

void main() {
  group('BaseParser foundational behaviour', () {
    test('skipSpaces removes whitespace and comments', () {
      final bytes =
          Uint8List.fromList(' \t\r\n%Comment here\r\n%Another\n123'.codeUnits);
      final parser = _TestParser(RandomAccessReadBuffer.fromBytes(bytes));

      parser.skipWhitespace();
      final first = parser.source.read();
      expect(String.fromCharCode(first), equals('1'));
    });

    test('readToken splits delimiters from names', () {
      final bytes = Uint8List.fromList(' 123 /Name'.codeUnits);
      final parser = _TestParser(RandomAccessReadBuffer.fromBytes(bytes));

      expect(parser.nextToken(), equals('123'));
      expect(parser.nextToken(), equals('/'));
      expect(parser.nextToken(), equals('Name'));
      expect(parser.nextToken(), isEmpty);
    });

    test('readInt parses signed integers and reports EOF', () {
      final bytes = Uint8List.fromList('   -456 78'.codeUnits);
      final parser = _TestParser(RandomAccessReadBuffer.fromBytes(bytes));

      expect(parser.nextInt(), equals(-456));
      expect(parser.nextInt(), equals(78));
      expect(parser.nextInt(), equals(-1));
    });

    test('readString stops at delimiters', () {
      final bytes = Uint8List.fromList('  token)'.codeUnits);
      final parser = _TestParser(RandomAccessReadBuffer.fromBytes(bytes));

      expect(parser.readGenericString(), equals('token'));
      expect(String.fromCharCode(parser.source.read()), equals(')'));
    });

    test('readLiteralString decodes escapes and octal values', () {
      final bytes = Uint8List.fromList('(Line\\nTwo\\053)'.codeUnits);
      final parser = _TestParser(RandomAccessReadBuffer.fromBytes(bytes));

      final literal = parser.readLiteral();
      expect(String.fromCharCodes(literal), equals('Line\nTwo+'));
    });

    test('readExpectedString enforces keywords and rewinds on mismatch', () {
      final bytes = Uint8List.fromList(' stream '.codeUnits);
      final parser = _TestParser(RandomAccessReadBuffer.fromBytes(bytes));

      parser.expectString('stream');
      expect(parser.source.read(), equals(-1));

      final mismatchBytes = Uint8List.fromList(' stram'.codeUnits);
      final mismatchParser =
          _TestParser(RandomAccessReadBuffer.fromBytes(mismatchBytes));

      expect(() => mismatchParser.expectString('stream'),
          throwsA(isA<IOException>()));
    });

    test('readExpectedChar validates single characters', () {
      final bytes = Uint8List.fromList('Aa'.codeUnits);
      final parser = _TestParser(RandomAccessReadBuffer.fromBytes(bytes));

      parser.expectChar('A');
      expect(String.fromCharCode(parser.source.read()), equals('a'));
    });

    test('readLong parses 64-bit range values', () {
      final bytes = Uint8List.fromList(
          ' 9223372036854775807 -9223372036854775808'.codeUnits);
      final parser = _TestParser(RandomAccessReadBuffer.fromBytes(bytes));

      expect(parser.nextLong(), equals(9223372036854775807));
      expect(parser.nextLong(), equals(-9223372036854775808));
    });

    test('skipWhiteSpaces removes trailing spaces and CRLF', () {
      final bytes = Uint8List.fromList('  \r\nAX'.codeUnits);
      final parser = _TestParser(RandomAccessReadBuffer.fromBytes(bytes));

      parser.skipPostStreamWhitespace();
      expect(String.fromCharCode(parser.source.read()), equals('A'));
    });

    test('skipLinebreak consumes standalone CRLF sequence', () {
      final bytes = Uint8List.fromList('\r\nZ'.codeUnits);
      final parser = _TestParser(RandomAccessReadBuffer.fromBytes(bytes));

      expect(parser.skipSingleLinebreak(), isTrue);
      expect(String.fromCharCode(parser.source.read()), equals('Z'));
    });
  });
}
