import 'dart:typed_data';

import '../../io/exceptions.dart';
import '../encoding/built_in_encoding.dart';
import '../encoding/standard_encoding.dart';
import 'token.dart';
import 'type1_font.dart';
import 'type1_lexer.dart';

/// Parser for Adobe Type 1 font programs.
class Type1Parser {
  static const int _eexecKey = 55665;
  static const int _charstringKey = 4330;

  late Type1Lexer _lexer;
  late Type1Font _font;

  /// Parses a Type 1 program represented by ASCII/binary segments.
  Type1Font parse(Uint8List segment1, Uint8List segment2) {
    _font = Type1Font(segment1, segment2);
    try {
      _parseAscii(segment1);
    } on FormatException catch (e) {
      throw IOException(e.toString());
    }
    if (segment2.isNotEmpty) {
      _parseBinary(segment2);
    }
    return _font;
  }

  void _parseAscii(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw IOException('ASCII segment of type 1 font is empty');
    }
    if (bytes.length < 2 || bytes[0] != 0x25 || bytes[1] != 0x21) {
      throw IOException('Invalid start of ASCII segment of type 1 font');
    }

    _lexer = Type1Lexer(bytes);

    final first = _lexer.peekToken();
    if (first != null &&
        first.kind == TokenKind.name &&
        first.text == 'FontDirectory') {
      _read(TokenKind.name, 'FontDirectory');
      _read(TokenKind.literal); // font name
      _read(TokenKind.name, 'known');
      _read(TokenKind.startProc);
      _readProcVoid();
      _read(TokenKind.startProc);
      _readProcVoid();
      _read(TokenKind.name, 'ifelse');
    }

    final lengthToken = _read(TokenKind.integer);
    final dictLength = lengthToken.intValue();
    _read(TokenKind.name, 'dict');
    _readMaybe(TokenKind.name, 'dup');
    _read(TokenKind.name, 'begin');

    for (var i = 0; i < dictLength; i++) {
      final token = _lexer.peekToken();
      if (token == null) {
        break;
      }
      if (token.kind == TokenKind.name) {
        final name = token.text;
        if (name == 'currentdict' || name == 'end') {
          break;
        }
      }

      final key = _read(TokenKind.literal).text!;
      switch (key) {
        case 'FontInfo':
        case 'Fontinfo':
          _readFontInfo(_readSimpleDict());
          break;
        case 'Metrics':
          _readSimpleDict();
          break;
        case 'Encoding':
          _readEncoding();
          break;
        default:
          _readSimpleValue(key);
          break;
      }
    }

    _readMaybe(TokenKind.name, 'currentdict');
    _read(TokenKind.name, 'end');

    _read(TokenKind.name, 'currentfile');
    _read(TokenKind.name, 'eexec');
  }

  void _readSimpleValue(String key) {
    final value = _readDictValue();
    switch (key) {
      case 'FontName':
        _font.fontName = value.first.text ?? '';
        break;
      case 'PaintType':
        _font.paintType = value.first.intValue();
        break;
      case 'FontType':
        _font.fontType = value.first.intValue();
        break;
      case 'FontMatrix':
        _font.fontMatrix = _arrayToNumbers(value);
        break;
      case 'FontBBox':
        _font.fontBBox = _arrayToNumbers(value);
        break;
      case 'UniqueID':
        _font.uniqueID = value.first.intValue();
        break;
      case 'StrokeWidth':
        _font.strokeWidth = value.first.floatValue();
        break;
      case 'FID':
        _font.fontID = value.first.text ?? '';
        break;
      default:
        break;
    }
  }

  void _readEncoding() {
    if (_lexer.peekKind(TokenKind.name)) {
      final name = _lexer.nextToken()!.text;
      if (name == 'StandardEncoding') {
        _font.encoding = StandardEncoding.instance;
      } else {
        throw IOException('Unknown encoding: $name');
      }
      _readMaybe(TokenKind.name, 'readonly');
      _read(TokenKind.name, 'def');
      return;
    }

    _read(TokenKind.integer);
    _readMaybe(TokenKind.name, 'array');

    while (!(_lexer.peekKind(TokenKind.name) &&
        const ['dup', 'readonly', 'def'].contains(_lexer.peekToken()!.text))) {
      if (_lexer.nextToken() == null) {
        throw IOException(
            'Incomplete data while reading encoding of type 1 font');
      }
    }

    final codeToName = <int, String>{};
    while (
        _lexer.peekKind(TokenKind.name) && _lexer.peekToken()!.text == 'dup') {
      _read(TokenKind.name, 'dup');
      final code = _read(TokenKind.integer).intValue();
      final name = _read(TokenKind.literal).text!;
      _read(TokenKind.name, 'put');
      codeToName[code] = name;
    }
    _font.encoding = BuiltInEncoding(codeToName);
    _readMaybe(TokenKind.name, 'readonly');
    _read(TokenKind.name, 'def');
  }

  List<num> _arrayToNumbers(List<Token> value) {
    final numbers = <num>[];
    for (var i = 1; i < value.length - 1; i++) {
      final token = value[i];
      if (token.kind == TokenKind.real) {
        numbers.add(token.floatValue());
      } else if (token.kind == TokenKind.integer) {
        numbers.add(token.intValue());
      } else {
        throw IOException(
            'Expected INTEGER or REAL but got $token at array position $i');
      }
    }
    return numbers;
  }

  void _readFontInfo(Map<String, List<Token>> fontInfo) {
    fontInfo.forEach((key, value) {
      switch (key) {
        case 'version':
          _font.version = value.first.text ?? '';
          break;
        case 'Notice':
          _font.notice = value.first.text ?? '';
          break;
        case 'FullName':
          _font.fullName = value.first.text ?? '';
          break;
        case 'FamilyName':
          _font.familyName = value.first.text ?? '';
          break;
        case 'Weight':
          _font.weight = value.first.text ?? '';
          break;
        case 'ItalicAngle':
          _font.italicAngle = value.first.floatValue();
          break;
        case 'isFixedPitch':
          _font.fixedPitch = value.first.booleanValue();
          break;
        case 'UnderlinePosition':
          _font.underlinePosition = value.first.floatValue();
          break;
        case 'UnderlineThickness':
          _font.underlineThickness = value.first.floatValue();
          break;
        default:
          break;
      }
    });
  }

  Map<String, List<Token>> _readSimpleDict() {
    final dict = <String, List<Token>>{};
    final length = _read(TokenKind.integer).intValue();
    _read(TokenKind.name, 'dict');
    _readMaybe(TokenKind.name, 'dup');

    if (_readMaybe(TokenKind.name, 'def') != null) {
      return dict;
    }

    _read(TokenKind.name, 'begin');

    for (var i = 0; i < length; i++) {
      final peek = _lexer.peekToken();
      if (peek == null) {
        break;
      }
      if (peek.kind == TokenKind.name && peek.text == 'end') {
        break;
      }
      if (peek.kind == TokenKind.name) {
        _read(TokenKind.name);
      }

      final key = _read(TokenKind.literal).text!;
      final value = _readDictValue();
      dict[key] = value;
    }

    _read(TokenKind.name, 'end');
    _readMaybe(TokenKind.name, 'readonly');
    _read(TokenKind.name, 'def');

    return dict;
  }

  List<Token> _readDictValue() {
    final value = _readValue();
    _readDef();
    return value;
  }

  List<Token> _readValue() {
    final value = <Token>[];
    final token = _lexer.nextToken();
    if (token == null) {
      return value;
    }
    value.add(token);

    if (token.kind == TokenKind.startArray) {
      var depth = 1;
      while (depth > 0) {
        final next = _lexer.nextToken();
        if (next == null) {
          return value;
        }
        value.add(next);
        if (next.kind == TokenKind.startArray) {
          depth++;
        } else if (next.kind == TokenKind.endArray) {
          depth--;
        }
      }
    } else if (token.kind == TokenKind.startProc) {
      value.addAll(_readProc());
    } else if (token.kind == TokenKind.startDict) {
      _read(TokenKind.endDict);
      return value;
    }

    _readPostScriptWrapper(value);
    return value;
  }

  void _readPostScriptWrapper(List<Token> value) {
    final peek = _lexer.peekToken();
    if (peek == null) {
      throw IOException('Missing start token for the system dictionary');
    }
    if (peek.text == 'systemdict') {
      _read(TokenKind.name, 'systemdict');
      _read(TokenKind.literal, 'internaldict');
      _read(TokenKind.name, 'known');

      _read(TokenKind.startProc);
      _readProcVoid();

      _read(TokenKind.startProc);
      _readProcVoid();

      _read(TokenKind.name, 'ifelse');
      _read(TokenKind.startProc);
      _read(TokenKind.name, 'pop');
      value
        ..clear()
        ..addAll(_readValue());
      _read(TokenKind.endProc);
      _read(TokenKind.name, 'if');
    }
  }

  List<Token> _readProc() {
    final value = <Token>[];
    var depth = 1;
    while (depth > 0) {
      final token = _lexer.nextToken();
      if (token == null) {
        throw IOException('Malformed procedure: missing token');
      }
      value.add(token);
      if (token.kind == TokenKind.startProc) {
        depth++;
      } else if (token.kind == TokenKind.endProc) {
        depth--;
      }
    }
    final executeOnly = _readMaybe(TokenKind.name, 'executeonly');
    if (executeOnly != null) {
      value.add(executeOnly);
    }
    return value;
  }

  void _readProcVoid() {
    var depth = 1;
    while (depth > 0) {
      final token = _lexer.nextToken();
      if (token == null) {
        throw IOException('Malformed procedure: missing token');
      }
      if (token.kind == TokenKind.startProc) {
        depth++;
      } else if (token.kind == TokenKind.endProc) {
        depth--;
      }
    }
    _readMaybe(TokenKind.name, 'executeonly');
  }

  void _parseBinary(Uint8List bytes) {
    Uint8List decrypted;
    if (_isBinary(bytes)) {
      decrypted = _decrypt(bytes, _eexecKey, 4);
    } else {
      decrypted = _decrypt(_hexToBinary(bytes), _eexecKey, 4);
    }

    _lexer = Type1Lexer(decrypted);

    Token? peek = _lexer.peekToken();
    while (peek != null && peek.text != 'Private') {
      _lexer.nextToken();
      peek = _lexer.peekToken();
    }
    if (peek == null) {
      throw IOException('/Private token not found');
    }

    _read(TokenKind.literal, 'Private');
    final dictLength = _read(TokenKind.integer).intValue();
    _read(TokenKind.name, 'dict');
    _readMaybe(TokenKind.name, 'dup');
    _read(TokenKind.name, 'begin');

    var lenIV = 4;

    for (var i = 0; i < dictLength; i++) {
      if (!_lexer.peekKind(TokenKind.literal)) {
        break;
      }
      final key = _read(TokenKind.literal).text!;
      switch (key) {
        case 'Subrs':
          _readSubrs(lenIV);
          break;
        case 'OtherSubrs':
          _readOtherSubrs();
          break;
        case 'lenIV':
          lenIV = _readDictValue().first.intValue();
          break;
        case 'ND':
          _read(TokenKind.startProc);
          _readMaybe(TokenKind.name, 'noaccess');
          _read(TokenKind.name, 'def');
          _read(TokenKind.endProc);
          _readMaybe(TokenKind.name, 'executeonly');
          _readMaybe(TokenKind.name, 'readonly');
          _read(TokenKind.name, 'def');
          break;
        case 'NP':
          _read(TokenKind.startProc);
          _readMaybe(TokenKind.name, 'noaccess');
          _read(TokenKind.name);
          _read(TokenKind.endProc);
          _readMaybe(TokenKind.name, 'executeonly');
          _readMaybe(TokenKind.name, 'readonly');
          _read(TokenKind.name, 'def');
          break;
        case 'RD':
          _read(TokenKind.startProc);
          _readProcVoid();
          _readMaybe(TokenKind.name, 'bind');
          _readMaybe(TokenKind.name, 'executeonly');
          _readMaybe(TokenKind.name, 'readonly');
          _read(TokenKind.name, 'def');
          break;
        default:
          _readPrivate(key, _readDictValue());
          break;
      }
    }

    while (!(_lexer.peekKind(TokenKind.literal) &&
        _lexer.peekToken()!.text == 'CharStrings')) {
      if (_lexer.nextToken() == null) {
        throw IOException('Missing \'CharStrings\' dictionary in type 1 font');
      }
    }

    _read(TokenKind.literal, 'CharStrings');
    _readCharStrings(lenIV);
  }

  void _readPrivate(String key, List<Token> value) {
    switch (key) {
      case 'BlueValues':
        _font.blueValues = _arrayToNumbers(value);
        break;
      case 'OtherBlues':
        _font.otherBlues = _arrayToNumbers(value);
        break;
      case 'FamilyBlues':
        _font.familyBlues = _arrayToNumbers(value);
        break;
      case 'FamilyOtherBlues':
        _font.familyOtherBlues = _arrayToNumbers(value);
        break;
      case 'BlueScale':
        _font.blueScale = value.first.floatValue();
        break;
      case 'BlueShift':
        _font.blueShift = value.first.intValue();
        break;
      case 'BlueFuzz':
        _font.blueFuzz = value.first.intValue();
        break;
      case 'StdHW':
        _font.stdHW = _arrayToNumbers(value);
        break;
      case 'StdVW':
        _font.stdVW = _arrayToNumbers(value);
        break;
      case 'StemSnapH':
        _font.stemSnapH = _arrayToNumbers(value);
        break;
      case 'StemSnapV':
        _font.stemSnapV = _arrayToNumbers(value);
        break;
      case 'ForceBold':
        _font.forceBold = value.first.booleanValue();
        break;
      case 'LanguageGroup':
        _font.languageGroup = value.first.intValue();
        break;
      default:
        break;
    }
  }

  void _readSubrs(int lenIV) {
    final length = _read(TokenKind.integer).intValue();
    _font.subrs
      ..clear()
      ..addAll(List<Uint8List>.generate(length, (_) => Uint8List(0)));
    _read(TokenKind.name, 'array');

    for (var i = 0; i < length; i++) {
      final peek = _lexer.peekToken();
      if (peek == null) {
        break;
      }
      if (!(peek.kind == TokenKind.name && peek.text == 'dup')) {
        break;
      }

      _read(TokenKind.name, 'dup');
      final index = _read(TokenKind.integer).intValue();
      _read(TokenKind.integer);
      final charstring = _read(TokenKind.charString);
      final decrypted = _decrypt(charstring.data, _charstringKey, lenIV);
      if (index >= 0 && index < _font.subrs.length) {
        _font.subrs[index] = decrypted;
      }
      _readPut();
    }
    _readDef();
  }

  void _readOtherSubrs() {
    final peek = _lexer.peekToken();
    if (peek == null) {
      throw IOException('Missing start token of OtherSubrs procedure');
    }
    if (peek.kind == TokenKind.startArray) {
      _readValue();
      _readDef();
      return;
    }

    final length = _read(TokenKind.integer).intValue();
    _read(TokenKind.name, 'array');
    for (var i = 0; i < length; i++) {
      _read(TokenKind.name, 'dup');
      _read(TokenKind.integer);
      _readValue();
      _readPut();
    }
    _readDef();
  }

  void _readCharStrings(int lenIV) {
    final length = _read(TokenKind.integer).intValue();
    _read(TokenKind.name, 'dict');
    _read(TokenKind.name, 'dup');
    _read(TokenKind.name, 'begin');

    for (var i = 0; i < length; i++) {
      final peek = _lexer.peekToken();
      if (peek == null) {
        break;
      }
      if (peek.kind == TokenKind.name && peek.text == 'end') {
        break;
      }
      final name = _read(TokenKind.literal).text!;
      _read(TokenKind.integer);
      final charstring = _read(TokenKind.charString);
      _font.charStrings[name] =
          _decrypt(charstring.data, _charstringKey, lenIV);
      _readDef();
    }

    _read(TokenKind.name, 'end');
  }

  void _readDef() {
    _readMaybe(TokenKind.name, 'readonly');
    _readMaybe(TokenKind.name, 'noaccess');
    var token = _read(TokenKind.name);
    switch (token.text) {
      case 'ND':
      case '|-':
        return;
      case 'noaccess':
        token = _read(TokenKind.name);
        break;
      default:
        break;
    }
    if (token.text == 'def') {
      return;
    }
    throw IOException('Found ${token.text} but expected ND');
  }

  void _readPut() {
    _readMaybe(TokenKind.name, 'readonly');
    var token = _read(TokenKind.name);
    switch (token.text) {
      case 'NP':
      case '|':
        return;
      case 'noaccess':
        token = _read(TokenKind.name);
        break;
      default:
        break;
    }
    if (token.text == 'put') {
      return;
    }
    throw IOException('Found ${token.text} but expected NP');
  }

  Token _read(TokenKind kind, [String? name]) {
    final token = _lexer.nextToken();
    if (token == null || token.kind != kind) {
      throw IOException('Found $token but expected $kind');
    }
    if (name != null && token.text != name) {
      throw IOException('Found ${token.text} but expected $name');
    }
    return token;
  }

  Token? _readMaybe(TokenKind kind, [String? name]) {
    final token = _lexer.peekToken();
    if (token == null || token.kind != kind) {
      return null;
    }
    if (name != null && token.text != name) {
      return null;
    }
    return _lexer.nextToken();
  }

  Uint8List _decrypt(Uint8List cipherBytes, int r, int n) {
    if (n == -1) {
      return Uint8List.fromList(cipherBytes);
    }
    if (cipherBytes.isEmpty || n > cipherBytes.length) {
      return Uint8List(0);
    }
    const c1 = 52845;
    const c2 = 22719;
    final plainBytes = Uint8List(cipherBytes.length - n);
    var key = r;
    for (var i = 0; i < cipherBytes.length; i++) {
      final cipher = cipherBytes[i];
      final plain = cipher ^ (key >> 8);
      if (i >= n) {
        plainBytes[i - n] = plain;
      }
      key = ((cipher + key) * c1 + c2) & 0xffff;
    }
    return plainBytes;
  }

  bool _isBinary(Uint8List bytes) {
    if (bytes.length < 4) {
      return true;
    }
    for (var i = 0; i < 4; i++) {
      final value = bytes[i];
      if (value != 0x0a &&
          value != 0x0d &&
          value != 0x20 &&
          value != 0x09 &&
          int.tryParse(String.fromCharCode(value), radix: 16) == null) {
        return true;
      }
    }
    return false;
  }

  Uint8List _hexToBinary(Uint8List bytes) {
    final hexDigits = <int>[];
    for (final value in bytes) {
      if (int.tryParse(String.fromCharCode(value), radix: 16) != null) {
        hexDigits.add(value);
      }
    }
    final out = Uint8List(hexDigits.length ~/ 2);
    var index = 0;
    for (var i = 0; i + 1 < hexDigits.length; i += 2) {
      final high = int.parse(String.fromCharCode(hexDigits[i]), radix: 16);
      final low = int.parse(String.fromCharCode(hexDigits[i + 1]), radix: 16);
      out[index++] = (high << 4) + low;
    }
    return out;
  }
}
