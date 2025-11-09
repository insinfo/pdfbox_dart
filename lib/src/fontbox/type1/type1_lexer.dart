import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import 'damaged_font_exception.dart';
import 'token.dart';

/// Lexer for the ASCII sections of a Type 1 font program.
class Type1Lexer {
  Type1Lexer(Uint8List bytes)
      : _bytes = bytes,
        _aheadToken = null {
    _aheadToken = _readToken(null);
  }

  static final Logger _log = Logger('fontbox.type1.Type1Lexer');

  final Uint8List _bytes;
  Token? _aheadToken;
  int _position = 0;
  int _openParens = 0;

  /// Consumes and returns the next token, or `null` when the stream ends.
  Token? nextToken() {
    final current = _aheadToken;
    _aheadToken = _readToken(current);
    return current;
  }

  /// Returns the next token without consuming it.
  Token? peekToken() => _aheadToken;

  /// Returns true when the next token has [kind].
  bool peekKind(TokenKind kind) => _aheadToken?.kind == kind;

  bool get _hasRemaining => _position < _bytes.length;

  int _getByte() {
    if (!_hasRemaining) {
      throw IOException('Premature end of buffer reached');
    }
    return _bytes[_position++];
  }

  int? _peekByte() => _hasRemaining ? _bytes[_position] : null;

  void _advance() {
    if (_hasRemaining) {
      _position++;
    }
  }

  Token? _readToken(Token? previous) {
    while (_hasRemaining) {
      final current = _getByte();
      if (_isWhitespace(current)) {
        continue;
      }
      if (current == 0) {
        _log.warning('NULL byte in Type 1 font, skipped');
        continue;
      }
      switch (current) {
        case 0x25: // %
          _skipComment();
          continue;
        case 0x28: // (
          return _readString();
        case 0x29: // )
          throw IOException('Unexpected closing parenthesis');
        case 0x5B: // [
          return Token.fromChar(current, TokenKind.startArray);
        case 0x7B: // {
          return Token.fromChar(current, TokenKind.startProc);
        case 0x5D: // ]
          return Token.fromChar(current, TokenKind.endArray);
        case 0x7D: // }
          return Token.fromChar(current, TokenKind.endProc);
        case 0x2F: // /
          final literal = _readRegular();
          if (literal == null) {
            throw DamagedFontException(
              'Could not read literal token at position $_position',
            );
          }
          return Token(literal, TokenKind.literal);
        case 0x3C: // <
          final next = _peekByte();
          if (next == 0x3C) {
            _advance();
            return Token('<<', TokenKind.startDict);
          }
          return Token.fromChar(current, TokenKind.name);
        case 0x3E: // >
          final nextGt = _peekByte();
          if (nextGt == 0x3E) {
            _advance();
            return Token('>>', TokenKind.endDict);
          }
          return Token.fromChar(current, TokenKind.name);
        default:
          final lexeme = _readRegular(startingWith: current);
          if (lexeme == null) {
            throw DamagedFontException(
              'Could not read token at position $_position',
            );
          }
          if (lexeme == 'RD' || lexeme == '-|') {
            if (previous == null || previous.kind != TokenKind.integer) {
              throw IOException('Expected integer before RD/-| token');
            }
            return _readCharString(previous.intValue());
          }
          final numeric = _asNumberToken(lexeme);
          if (numeric != null) {
            return numeric;
          }
          return Token(lexeme, TokenKind.name);
      }
    }
    return null;
  }

  String? _readRegular({int? startingWith}) {
    final buffer = StringBuffer();
    if (startingWith != null) {
      buffer.writeCharCode(startingWith);
    }
    while (_hasRemaining) {
      final next = _peekByte();
      if (next == null) {
        break;
      }
      if (_isWhitespace(next) ||
          next == 0x28 ||
          next == 0x29 ||
          next == 0x3C ||
          next == 0x3E ||
          next == 0x5B ||
          next == 0x5D ||
          next == 0x7B ||
          next == 0x7D ||
          next == 0x2F ||
          next == 0x25) {
        break;
      }
      buffer.writeCharCode(_getByte());
    }
    if (buffer.isEmpty) {
      return null;
    }
    return buffer.toString();
  }

  void _skipComment() {
    while (_hasRemaining) {
      final current = _getByte();
      if (current == 0x0A || current == 0x0D) {
        break;
      }
    }
  }

  Token? _asNumberToken(String value) {
    if (value.contains('#')) {
      final parts = value.split('#');
      if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        final radix = int.tryParse(parts[0]);
        if (radix == null) {
          throw IOException('Invalid radix specification: ${parts[0]}');
        }
        try {
          final parsed = int.parse(parts[1], radix: radix);
          return Token(parsed.toString(), TokenKind.integer);
        } on FormatException {
          throw IOException('Invalid number "$value"');
        }
      }
      return null;
    }
    final intValue = int.tryParse(value);
    if (intValue != null) {
      return Token(value, TokenKind.integer);
    }
    final doubleValue = double.tryParse(value);
    if (doubleValue != null) {
      return Token(value, TokenKind.real);
    }
    if (value == 'true' || value == 'false') {
      return Token(value, TokenKind.name);
    }
    return null;
  }

  Token _readString() {
    final buffer = StringBuffer();
    while (_hasRemaining) {
      final current = _getByte();
      switch (current) {
        case 0x28: // (
          _openParens++;
          buffer.writeCharCode(current);
          break;
        case 0x29: // )
          if (_openParens == 0) {
            return Token(buffer.toString(), TokenKind.string);
          }
          _openParens--;
          buffer.writeCharCode(current);
          break;
        case 0x5C: // \
          final escaped = _getByte();
          switch (escaped) {
            case 0x6E: // n
            case 0x72: // r
              buffer.write('\n');
              break;
            case 0x74: // t
              buffer.write('\t');
              break;
            case 0x62: // b
              buffer.write('\b');
              break;
            case 0x66: // f
              buffer.write('\f');
              break;
            case 0x5C: // \
            case 0x28: // (
            case 0x29: // )
              buffer.writeCharCode(escaped);
              break;
            default:
              if (_isDigit(escaped)) {
                final digits = <int>[escaped, _getByte(), _getByte()];
                final numStr = String.fromCharCodes(digits);
                final value = int.tryParse(numStr, radix: 8);
                if (value == null) {
                  throw IOException('Invalid octal escape: $numStr');
                }
                buffer.writeCharCode(value);
              }
              break;
          }
          break;
        case 0x0D:
        case 0x0A:
          buffer.write('\n');
          break;
        default:
          buffer.writeCharCode(current);
          break;
      }
    }
    return Token(buffer.toString(), TokenKind.string);
  }

  Token _readCharString(int length) {
    if (length > _bytes.length) {
      throw IOException('CharString length $length exceeds input size');
    }
    if (!_hasRemaining) {
      throw IOException('Missing charstring data');
    }
    final separator = _getByte();
    if (!_isWhitespace(separator)) {
      // The original Java implementation assumes a space; we gracefully allow any byte.
      if (_position > 0) {
        _position--;
      }
    }
    if (_position + length > _bytes.length) {
      throw IOException('Premature end of charstring data');
    }
    final data = Uint8List(length);
    for (var i = 0; i < length; i++) {
      data[i] = _getByte();
    }
    return Token.fromData(data);
  }

  bool _isWhitespace(int value) {
    return value == 0x20 || // space
        value == 0x0D ||
        value == 0x0A ||
        value == 0x09 ||
        value == 0x0C ||
        value == 0x00;
  }

  bool _isDigit(int value) => value >= 0x30 && value <= 0x39;
}
