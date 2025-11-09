import 'dart:typed_data';

/// Token categories produced by [Type1Lexer].
enum TokenKind {
  none,
  string,
  name,
  literal,
  real,
  integer,
  startArray,
  endArray,
  startProc,
  endProc,
  startDict,
  endDict,
  charString,
}

/// Representation of a lexical token inside a Type 1 program.
class Token {
  Token(String text, this.kind)
      : text = text,
        _data = null;

  Token.fromChar(int charCode, this.kind)
      : text = String.fromCharCode(charCode),
        _data = null;

  Token.fromData(Uint8List data)
      : kind = TokenKind.charString,
        _data = Uint8List.fromList(data),
        text = null;

  final TokenKind kind;
  final String? text;
  final Uint8List? _data;

  Uint8List get data {
    final value = _data;
    if (value == null) {
      throw StateError('Token does not carry binary data');
    }
    return value;
  }

  int intValue() {
    final value = text;
    if (value == null) {
      throw StateError('Token does not carry numeric text');
    }
    return double.parse(value).toInt();
  }

  double floatValue() {
    final value = text;
    if (value == null) {
      throw StateError('Token does not carry numeric text');
    }
    return double.parse(value);
  }

  bool booleanValue() => text == 'true';

  @override
  String toString() {
    if (kind == TokenKind.charString) {
      return 'Token[kind=charString, data=${_data?.length ?? 0} bytes]';
    }
    return 'Token[kind=$kind, text=$text]';
  }
}
