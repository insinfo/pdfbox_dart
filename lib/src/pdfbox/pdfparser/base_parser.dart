import 'dart:typed_data';

import '../../io/exceptions.dart';
import '../../io/random_access_read.dart';
import '../cos/cos_stream.dart';
import '../filter/decode_options.dart';
import 'parsed_stream.dart';

/// Shared parsing utilities mirroring PDFBox's BaseParser behaviour.
abstract class BaseParser {
  BaseParser(this.source);

  static const int _maxLengthLong = 19; // Long.MAX_VALUE decimal length.

  static const int _asciiNull = 0x00;
  static const int _asciiTab = 0x09;
  static const int _asciiLf = 0x0a;
  static const int _asciiFormFeed = 0x0c;
  static const int _asciiCr = 0x0d;
  static const int _asciiSpace = 0x20;
  static const int _asciiZero = 0x30;
  static const int _asciiNine = 0x39;
  static const int _percent = 0x25; // '%'
  static const int _minus = 0x2d;
  static const int _plus = 0x2b;

  final RandomAccessRead source;

  /// True when the underlying source has been exhausted.
  bool get isEOF => source.isEOF;

  /// Returns true if [c] represents a whitespace character (Table 1 of ISO 32000-1).
  static bool isWhitespace(int c) {
    switch (c) {
      case _asciiNull:
      case _asciiTab:
      case _asciiFormFeed:
      case _asciiLf:
      case _asciiCr:
      case _asciiSpace:
        return true;
      default:
        return false;
    }
  }

  /// Returns true if [c] is an end-of-line marker.
  static bool isEOL(int c) => c == _asciiLf || c == _asciiCr;

  /// Returns true if [c] is a line feed character.
  static bool isLF(int c) => c == _asciiLf;

  /// Returns true if [c] is a carriage return character.
  static bool isCR(int c) => c == _asciiCr;

  /// Returns true if [c] is a decimal digit.
  static bool isDigit(int c) => c >= _asciiZero && c <= _asciiNine;

  /// Returns true if [c] terminates PDF names/tokens.
  static bool isEndOfName(int c) {
    switch (c) {
      case _asciiSpace:
      case _asciiCr:
      case _asciiLf:
      case _asciiTab:
      case 0x3e: // '>'
      case 0x3c: // '<'
      case 0x5b: // '['
      case 0x2f: // '/'
      case 0x5d: // ']'
      case 0x29: // ')'
      case 0x28: // '('
      case _asciiNull:
      case _asciiFormFeed:
      case 0x25: // '%'
      case -1:
        return true;
      default:
        return false;
    }
  }

  /// Returns true if [c] is the ASCII space character.
  static bool _isSpace(int c) => c == _asciiSpace;

  /// Advances past whitespace and comment lines, positioning the cursor on the next token.
  void skipSpaces() {
    var c = source.read();
    while (isWhitespace(c) || c == _percent) {
      if (c == _percent) {
        // Skip comment until end-of-line.
        c = source.read();
        while (c != -1 && !isEOL(c)) {
          c = source.read();
        }
      } else {
        c = source.read();
      }
    }
    if (c != -1) {
      source.rewind(1);
    }
  }

  /// Skips trailing spaces and an optional line break following a stream keyword.
  void skipWhiteSpaces() {
    var whitespace = source.read();
    while (_isSpace(whitespace)) {
      whitespace = source.read();
    }
    if (!_skipLinebreak(whitespace) && whitespace != -1) {
      source.rewind(1);
    }
  }

  /// Attempts to skip a single CR, LF or CRLF sequence.
  bool skipLinebreak() {
    final first = source.read();
    if (!_skipLinebreak(first)) {
      if (first != -1) {
        source.rewind(1);
      }
      return false;
    }
    return true;
  }

  bool _skipLinebreak(int linebreak) {
    if (isCR(linebreak)) {
      final next = source.read();
      if (!isLF(next) && next != -1) {
        source.rewind(1);
      }
      return true;
    }
    if (isLF(linebreak)) {
      return true;
    }
    return false;
  }

  /// Reads the next lexical token (name/operator/number delimiter) from the stream.
  /// Returns an empty string when EOF is reached.
  String readToken() {
    skipSpaces();
    final buffer = StringBuffer();
    var c = source.read();
    if (c == -1) {
      return '';
    }
    if (isEndOfName(c)) {
      return String.fromCharCode(c);
    }
    while (c != -1 && !isEndOfName(c)) {
      buffer.writeCharCode(c);
      c = source.read();
    }
    if (c != -1) {
      source.rewind(1);
    }
    return buffer.toString();
  }

  /// Reads the next generic string token until a delimiter is found.
  String readString() {
    skipSpaces();
    final buffer = StringBuffer();
    var c = source.read();
    while (c != -1 && !isEndOfName(c)) {
      buffer.writeCharCode(c);
      c = source.read();
    }
    if (c != -1) {
      source.rewind(1);
    }
    return buffer.toString();
  }

  /// Parses a literal string, handling escape sequences and balanced parentheses.
  Uint8List readLiteralString() {
    readExpectedChar('('.codeUnitAt(0));
    final buffer = BytesBuilder(copy: false);
    var braces = 1;
    var c = source.read();
    while (braces > 0 && c != -1) {
      final ch = c;
      var nextC = -2;
      if (ch == ')'.codeUnitAt(0)) {
        braces--;
        braces = _checkForEndOfString(braces);
        if (braces != 0) {
          buffer.addByte(ch);
        }
      } else if (ch == '('.codeUnitAt(0)) {
        braces++;
        buffer.addByte(ch);
      } else if (ch == '\\'.codeUnitAt(0)) {
        final next = source.read();
        switch (next) {
          case 0x6e: // 'n'
            buffer.addByte(_asciiLf);
            break;
          case 0x72: // 'r'
            buffer.addByte(_asciiCr);
            break;
          case 0x74: // 't'
            buffer.addByte(_asciiTab);
            break;
          case 0x62: // 'b'
            buffer.addByte(0x08); // backspace
            break;
          case 0x66: // 'f'
            buffer.addByte(_asciiFormFeed);
            break;
          case 0x29: // ')'
            braces = _checkForEndOfString(braces);
            if (braces != 0) {
              buffer.addByte(0x29);
            } else {
              buffer.addByte('\\'.codeUnitAt(0));
            }
            break;
          case 0x28: // '('
          case 0x5c: // '\\'
            buffer.addByte(next);
            break;
          case _asciiLf:
          case _asciiCr:
            c = source.read();
            while (isEOL(c) && c != -1) {
              c = source.read();
            }
            nextC = c;
            break;
          case 0x30:
          case 0x31:
          case 0x32:
          case 0x33:
          case 0x34:
          case 0x35:
          case 0x36:
          case 0x37:
            final octal = StringBuffer()..writeCharCode(next);
            c = source.read();
            var digit = c;
            if (digit != -1 && digit >= _asciiZero && digit <= 0x37) {
              octal.writeCharCode(digit);
              c = source.read();
              digit = c;
              if (digit != -1 && digit >= _asciiZero && digit <= 0x37) {
                octal.writeCharCode(digit);
              } else {
                nextC = c;
              }
            } else {
              nextC = c;
            }

            final value = int.tryParse(octal.toString(), radix: 8);
            if (value == null) {
              throw IOException(
                  'Error: Expected octal character, actual=\'${octal.toString()}\'');
            }
            buffer.addByte(value);
            break;
          default:
            buffer.addByte(next);
        }
      } else {
        buffer.addByte(ch);
      }
      if (nextC != -2) {
        c = nextC;
      } else {
        c = source.read();
      }
    }
    if (c != -1) {
      source.rewind(1);
    }
    return buffer.toBytes();
  }

  /// Reads and validates [expected] against the upcoming bytes in the source.
  void readExpectedString(List<int> expected,
      {bool skipSurroundingSpaces = true}) {
    if (skipSurroundingSpaces) {
      skipSpaces();
    }
    for (final codePoint in expected) {
      final actual = source.read();
      if (actual != codePoint) {
        final expectedStr = String.fromCharCodes(expected);
        final actualDisplay =
            actual == -1 ? 'EOF' : String.fromCharCode(actual);
        throw IOException(
          "Expected string '$expectedStr' but found '$actualDisplay' at offset ${source.position} while matching",
        );
      }
    }
    if (skipSurroundingSpaces) {
      skipSpaces();
    }
  }

  /// Reads the next byte and asserts it matches [expected].
  void readExpectedChar(int expected) {
    final actual = source.read();
    if (actual != expected) {
      throw IOException(
        "expected='${String.fromCharCode(expected)}' actual='${actual == -1 ? 'EOF' : String.fromCharCode(actual)}' at offset ${source.position}",
      );
    }
  }

  /// Reads a signed integer from the current position, returning -1 on EOF.
  int readInt() {
    skipSpaces();
    final token = _readNumericToken();
    if (token.lexeme.isEmpty) {
      return -1;
    }
    if (token.digitCount == 0) {
      source.rewind(token.length);
      throw IOException(
        "Error: Expected an integer type at offset ${source.position}, instead got '${token.lexeme}'",
      );
    }
    final value = int.tryParse(token.lexeme);
    if (value == null) {
      source.rewind(token.length);
      throw IOException(
        "Error: Expected an integer type at offset ${source.position}, instead got '${token.lexeme}'",
      );
    }
    return value;
  }

  /// Reads a long value from the stream, mirroring PDFBox semantics.
  int readLong() {
    skipSpaces();
    final token = _readNumericToken();
    if (token.lexeme.isEmpty) {
      return -1;
    }
    if (token.digitCount == 0) {
      source.rewind(token.length);
      throw IOException(
        "Error: Expected a long type at offset ${source.position}, instead got '${token.lexeme}'",
      );
    }
    final value = int.tryParse(token.lexeme);
    if (value == null) {
      source.rewind(token.length);
      throw IOException(
        "Error: Expected a long type at offset ${source.position}, instead got '${token.lexeme}'",
      );
    }
    return value;
  }

  ParsedStream resolveStream(
    COSStream stream, {
    bool decode = true,
    DecodeOptions options = DecodeOptions.defaultOptions,
    bool retainEncodedCopy = true,
  }) {
    final encoded = retainEncodedCopy ? stream.encodedBytes(copy: false) : null;
    if (!decode) {
      return ParsedStream(stream: stream, encoded: encoded);
    }

    if (stream.filters.isEmpty) {
      return ParsedStream(stream: stream, encoded: encoded, decoded: encoded);
    }

    final pipelineResult = stream.decodeWithResult(options: options);
    if (pipelineResult == null) {
      return ParsedStream(stream: stream, encoded: encoded);
    }

    return ParsedStream(
      stream: stream,
      encoded: encoded,
      decoded: pipelineResult.data,
      decodeResults: pipelineResult.results,
    );
  }

  int _checkForEndOfString(int braces) {
    if (braces == 0) {
      return 0;
    }
    final lookAhead = Uint8List(3);
    final amountRead = source.readBuffer(lookAhead);
    if (amountRead > 0) {
      source.rewind(amountRead);
    }
    if (amountRead < 3) {
      return braces;
    }
    final first = lookAhead[0];
    final second = lookAhead[1];
    final third = lookAhead[2];
    final nextIsObject = (isCR(first) || isLF(first)) &&
        (second == '/'.codeUnitAt(0) || second == '>'.codeUnitAt(0));
    final nextIsObjectWithCrLf = isCR(first) &&
        isLF(second) &&
        (third == '/'.codeUnitAt(0) || third == '>'.codeUnitAt(0));
    return (nextIsObject || nextIsObjectWithCrLf) ? 0 : braces;
  }

  _NumericToken _readNumericToken() {
    final buffer = StringBuffer();
    var consumed = 0;
    var digitCount = 0;

    var c = source.read();
    if (c == -1) {
      return const _NumericToken('', 0, 0);
    }

    if (c == _minus || c == _plus) {
      buffer.writeCharCode(c);
      consumed++;
      c = source.read();
    }

    while (c != -1 && isDigit(c)) {
      buffer.writeCharCode(c);
      consumed++;
      digitCount++;
      if (digitCount > _maxLengthLong) {
        throw IOException(
          "Number '${buffer.toString()}' is getting too long, stop reading at offset ${source.position}",
        );
      }
      c = source.read();
    }

    if (c != -1) {
      source.rewind(1);
    }

    return _NumericToken(buffer.toString(), consumed, digitCount);
  }

  /// Reads bytes until the next end-of-line marker and returns the collected characters.
  /// Throws if invoked at EOF to mirror PDFBox behaviour when a line is expected.
  String readLine() {
  if (source.isEOF) {
      throw IOException(
          'Error: End-of-File, expected line at offset ${source.position}');
    }

    final buffer = StringBuffer();
    var c = source.read();
    while (c != -1 && !isEOL(c)) {
      buffer.writeCharCode(c);
      c = source.read();
    }
    if (c == -1) {
      return buffer.toString();
    }
    if (isCR(c) && isLF(source.peek())) {
      source.read();
    }
    return buffer.toString();
  }
}

class _NumericToken {
  const _NumericToken(this.lexeme, this.length, this.digitCount);

  final String lexeme;
  final int length;
  final int digitCount;
}
