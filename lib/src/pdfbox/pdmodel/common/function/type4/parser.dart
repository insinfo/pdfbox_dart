enum _State { newline, whitespace, comment, token }

class Parser {
  Parser._();

  static void parse(String input, SyntaxHandler handler) {
    final tokenizer = _Tokenizer(input, handler);
    tokenizer.tokenize();
  }
}

abstract class SyntaxHandler {
  void newLine(String text);

  void whitespace(String text);

  void token(String text);

  void comment(String text);
}

abstract class AbstractSyntaxHandler implements SyntaxHandler {
  @override
  void newLine(String text) {}

  @override
  void whitespace(String text) {}

  @override
  void comment(String text) {}
}

class _Tokenizer {
  _Tokenizer(this.input, this.handler);

  static const int _nul = 0x00;
  static const int _eot = 0x04;
  static const int _tab = 0x09;
  static const int _ff = 0x0c;
  static const int _cr = 0x0d;
  static const int _lf = 0x0a;
  static const int _space = 0x20;

  final String input;
  final SyntaxHandler handler;
  var _index = 0;
  var _state = _State.whitespace;

  bool get _hasMore => _index < input.length;

  int _currentChar() => input.codeUnitAt(_index);

  int _nextChar() {
    _index++;
    if (!_hasMore) {
      return _eot;
    }
    return _currentChar();
  }

  int _peek() {
    if (_index < input.length - 1) {
      return input.codeUnitAt(_index + 1);
    }
    return _eot;
  }

  _State _nextState() {
    if (!_hasMore) {
      return _state;
    }
    final ch = _currentChar();
    switch (ch) {
      case _cr:
      case _lf:
      case _ff:
        _state = _State.newline;
        break;
      case _nul:
      case _tab:
      case _space:
        _state = _State.whitespace;
        break;
      case 0x25: // '%'
        _state = _State.comment;
        break;
      default:
        _state = _State.token;
        break;
    }
    return _state;
  }

  void tokenize() {
    while (_hasMore) {
      switch (_nextState()) {
        case _State.newline:
          _scanNewLine();
          break;
        case _State.whitespace:
          _scanWhitespace();
          break;
        case _State.comment:
          _scanComment();
          break;
        case _State.token:
          _scanToken();
          break;
      }
    }
  }

  void _scanNewLine() {
    final buffer = StringBuffer();
    final ch = _currentChar();
    buffer.writeCharCode(ch);
    if (ch == _cr && _peek() == _lf) {
      buffer.writeCharCode(_nextChar());
    }
    handler.newLine(buffer.toString());
    _nextChar();
  }

  void _scanWhitespace() {
    final buffer = StringBuffer();
    buffer.writeCharCode(_currentChar());
    while (_hasMore) {
      final ch = _nextChar();
      switch (ch) {
        case _nul:
        case _tab:
        case _space:
          buffer.writeCharCode(ch);
          break;
        default:
          handler.whitespace(buffer.toString());
          return;
      }
    }
    handler.whitespace(buffer.toString());
  }

  void _scanComment() {
    final buffer = StringBuffer();
    buffer.writeCharCode(_currentChar());
    while (_hasMore) {
      final ch = _nextChar();
      switch (ch) {
        case _cr:
        case _lf:
        case _ff:
          handler.comment(buffer.toString());
          return;
        default:
          buffer.writeCharCode(ch);
      }
    }
    handler.comment(buffer.toString());
  }

  void _scanToken() {
    final buffer = StringBuffer();
    var ch = _currentChar();
    buffer.writeCharCode(ch);
    if (ch == 0x7b || ch == 0x7d) {
      handler.token(buffer.toString());
      _nextChar();
      return;
    }
    while (_hasMore) {
      ch = _nextChar();
      switch (ch) {
        case _nul:
        case _tab:
        case _space:
        case _cr:
        case _lf:
        case _ff:
        case _eot:
        case 0x7b:
        case 0x7d:
          handler.token(buffer.toString());
          return;
        default:
          buffer.writeCharCode(ch);
      }
    }
    handler.token(buffer.toString());
  }
}
