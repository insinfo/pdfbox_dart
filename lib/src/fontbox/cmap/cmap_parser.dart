import 'dart:typed_data';

import '../../io/random_access_read.dart';
import 'predefined_cmap_repository.dart';
import 'cmap.dart';
import 'cmap_strings.dart';
import 'codespace_range.dart';

/// Parses CMap streams into [CMap] instances.
class CMapParser {
  static const String _markEndOfDictionary = '>>';
  static const String _markEndOfArray = ']';

  CMapParser({bool strictMode = false, RandomAccessRead Function(String name)? externalCMapLoader})
      : _strictMode = strictMode,
        _externalCMapLoader = externalCMapLoader ?? PredefinedCMapRepository.open;

  bool _strictMode;
  final RandomAccessRead Function(String name) _externalCMapLoader;
  final Uint8List _tokenBuffer = Uint8List(512);

  CMap parsePredefined(String name) {
    final randomAccessRead = _externalCMapLoader(name);
    try {
      _strictMode = false;
      return parse(randomAccessRead);
    } finally {
      randomAccessRead.close();
    }
  }

  CMap parse(RandomAccessRead input) {
    final result = CMap();
    Object? previousToken;
    Object? token = _parseNextToken(input);
    while (token != null) {
      if (token is _Operator) {
        if (token.name == 'endcmap') {
          break;
        }
        if (token.name == 'usecmap' && previousToken is _LiteralName) {
          _parseUsecmap(previousToken, result);
        } else if (previousToken is num) {
          final count = previousToken;
          switch (token.name) {
            case 'begincodespacerange':
              _parseBegincodespacerange(count, input, result);
              break;
            case 'beginbfchar':
              _parseBeginbfchar(count, input, result);
              break;
            case 'beginbfrange':
              _parseBeginbfrange(count, input, result);
              break;
            case 'begincidchar':
              _parseBegincidchar(count, input, result);
              break;
            case 'begincidrange':
              if (count is int) {
                _parseBegincidrange(count, input, result);
              }
              break;
            default:
              break;
          }
        }
      } else if (token is _LiteralName) {
        _parseLiteralName(token, input, result);
      }
      previousToken = token;
      token = _parseNextToken(input);
    }
    return result;
  }

  void _parseUsecmap(_LiteralName useName, CMap target) {
    final source = _externalCMapLoader(useName.value);
    try {
      final useMap = parse(source);
      target.useCmap(useMap);
    } finally {
      source.close();
    }
  }

  void _parseLiteralName(_LiteralName literal, RandomAccessRead input, CMap result) {
    switch (literal.value) {
      case 'WMode':
        final next = _parseNextToken(input);
        if (next is int) {
          result.wMode = next;
        }
        break;
      case 'CMapName':
        final next = _parseNextToken(input);
        if (next is _LiteralName) {
          result.name = next.value;
        }
        break;
      case 'CMapVersion':
        final next = _parseNextToken(input);
        if (next is num) {
          result.version = next.toString();
        } else if (next is String) {
          result.version = next;
        }
        break;
      case 'CMapType':
        final next = _parseNextToken(input);
        if (next is int) {
          result.type = next;
        }
        break;
      case 'Registry':
        final next = _parseNextToken(input);
        if (next is String) {
          result.registry = next;
        }
        break;
      case 'Ordering':
        final next = _parseNextToken(input);
        if (next is String) {
          result.ordering = next;
        }
        break;
      case 'Supplement':
        final next = _parseNextToken(input);
        if (next is int) {
          result.supplement = next;
        }
        break;
      default:
        break;
    }
  }

  void _parseBegincodespacerange(num count, RandomAccessRead input, CMap result) {
    for (var i = 0; i < count.toInt(); i++) {
      final startToken = _parseNextToken(input);
      if (startToken is _Operator) {
        _checkExpectedOperator(startToken, 'endcodespacerange', 'codespacerange');
        break;
      }
      if (startToken is! Uint8List) {
        throw FormatException('start range missing');
      }
      final endToken = _parseByteArray(input);
      try {
        result.addCodespaceRange(CodespaceRange(startToken, endToken));
      } on ArgumentError catch (error) {
        throw FormatException(error.message);
      }
    }
  }

  void _parseBeginbfchar(num count, RandomAccessRead input, CMap result) {
    for (var i = 0; i < count.toInt(); i++) {
      var nextToken = _parseNextToken(input);
      if (nextToken is _Operator) {
        _checkExpectedOperator(nextToken, 'endbfchar', 'bfchar');
        break;
      }
      if (nextToken is! Uint8List) {
        throw FormatException('input code missing');
      }
      final inputCode = nextToken;
      nextToken = _parseNextToken(input);
      if (nextToken is Uint8List) {
        result.addCharMapping(inputCode, _createStringFromBytes(nextToken));
      } else if (nextToken is _LiteralName) {
        result.addCharMapping(inputCode, nextToken.value);
      } else {
        throw FormatException('Expected byte array or literal name, got $nextToken');
      }
    }
  }

  void _parseBegincidrange(int count, RandomAccessRead input, CMap result) {
    for (var i = 0; i < count; i++) {
      var token = _parseNextToken(input);
      if (token is _Operator) {
        _checkExpectedOperator(token, 'endcidrange', 'cidrange');
        break;
      }
      if (token is! Uint8List) {
        throw FormatException('start code missing');
      }
      final startCode = token;
      final endCode = _parseByteArray(input);
      final cid = _parseInteger(input);
      if (startCode.length != endCode.length) {
        throw FormatException('CID range bounds must have identical lengths');
      }
      if (_arraysEqual(startCode, endCode)) {
        result.addCIDMapping(startCode, cid);
      } else {
        result.addCIDRange(startCode, endCode, cid);
      }
    }
  }

  void _parseBegincidchar(num count, RandomAccessRead input, CMap result) {
    for (var i = 0; i < count.toInt(); i++) {
      final token = _parseNextToken(input);
      if (token is _Operator) {
        _checkExpectedOperator(token, 'endcidchar', 'cidchar');
        break;
      }
      if (token is! Uint8List) {
        throw FormatException('input code missing');
      }
      final cid = _parseInteger(input);
      result.addCIDMapping(token, cid);
    }
  }

  void _parseBeginbfrange(num count, RandomAccessRead input, CMap result) {
    for (var i = 0; i < count.toInt(); i++) {
      var token = _parseNextToken(input);
      if (token is _Operator) {
        _checkExpectedOperator(token, 'endbfrange', 'bfrange');
        break;
      }
      if (token is! Uint8List) {
        throw FormatException('start code missing');
      }
      final startCode = Uint8List.fromList(token);
      token = _parseNextToken(input);
      if (token is _Operator) {
        _checkExpectedOperator(token, 'endbfrange', 'bfrange');
        break;
      }
      if (token is! Uint8List) {
        throw FormatException('end code missing');
      }
      final endCode = token;
      final start = CMap.toInt(startCode);
      final end = CMap.toInt(endCode);
      if (end < start) {
        break;
      }
      final mappingToken = _parseNextToken(input);
      if (mappingToken is Uint8List && mappingToken.isNotEmpty) {
        if (mappingToken.length == 2 && start == 0 && end == 0xffff &&
            mappingToken[0] == 0 && mappingToken[1] == 0) {
          for (var high = 0; high < 256; high++) {
            startCode[0] = high;
            startCode[1] = 0;
            mappingToken[0] = high;
            mappingToken[1] = 0;
            _addMappingFromBfrangeFixed(result, startCode, 256, mappingToken);
          }
        } else {
          _addMappingFromBfrangeFixed(result, startCode, end - start + 1, mappingToken);
        }
      } else if (mappingToken is List<Object?>) {
        final entries = mappingToken.whereType<Uint8List>().toList();
        if (entries.isNotEmpty && entries.length >= end - start) {
          _addMappingFromBfrangeList(result, startCode, entries);
        }
      }
    }
  }

  void _addMappingFromBfrangeList(CMap cmap, Uint8List startCode, List<Uint8List> tokens) {
    final code = Uint8List.fromList(startCode);
    for (final bytes in tokens) {
      cmap.addCharMapping(code, _createStringFromBytes(bytes));
      _increment(code, code.length - 1, false);
    }
  }

  void _addMappingFromBfrangeFixed(CMap cmap, Uint8List startCode, int count, Uint8List token) {
    final code = Uint8List.fromList(startCode);
    final value = Uint8List.fromList(token);
    for (var i = 0; i < count; i++) {
      cmap.addCharMapping(code, _createStringFromBytes(value));
      if (!_increment(value, value.length - 1, _strictMode)) {
        break;
      }
      _increment(code, code.length - 1, false);
    }
  }

  int _parseInteger(RandomAccessRead input) {
    final token = _parseNextToken(input);
    if (token is int) {
      return token;
    }
    throw FormatException('Expected integer value');
  }

  Uint8List _parseByteArray(RandomAccessRead input) {
    final token = _parseNextToken(input);
    if (token is Uint8List) {
      return token;
    }
    throw FormatException('Expected byte array');
  }

  void _checkExpectedOperator(_Operator operator, String expected, String rangeName) {
    if (operator.name != expected) {
      throw FormatException('~$rangeName contains unexpected operator ${operator.name}');
    }
  }

  Object? _parseNextToken(RandomAccessRead input) {
    var nextByte = input.read();
    while (_isWhitespace(nextByte)) {
      nextByte = input.read();
    }
    switch (nextByte) {
      case -1:
        return null;
      case 0x25: // %
        return _readLine(input, nextByte);
      case 0x28: // (
        return _readString(input);
      case 0x3e: // >
        if (input.read() == 0x3e) {
          return _markEndOfDictionary;
        }
        throw FormatException('Expected end of dictionary');
      case 0x5d: // ]
        return _markEndOfArray;
      case 0x5b: // [
        return _readArray(input);
      case 0x3c: // <
        return _readDictionaryOrHex(input);
      case 0x2f: // /
        return _readLiteralName(input);
      case 0x2d: // potential negative number or operator
        final peek = input.peek();
        if (peek >= 0x30 && peek <= 0x39) {
          return _readNumber(input, nextByte);
        }
        return _readOperator(input, nextByte);
      default:
        if (nextByte >= 0x30 && nextByte <= 0x39) {
          return _readNumber(input, nextByte);
        }
        return _readOperator(input, nextByte);
    }
  }

  List<Object> _readArray(RandomAccessRead input) {
    final result = <Object>[];
    var token = _parseNextToken(input);
    while (token != null && token != _markEndOfArray) {
      result.add(token);
      token = _parseNextToken(input);
    }
    return result;
  }

  String _readString(RandomAccessRead input) {
    final buffer = StringBuffer();
    var byte = input.read();
    while (byte != -1 && byte != 0x29) {
      buffer.writeCharCode(byte);
      byte = input.read();
    }
    return buffer.toString();
  }

  String _readLine(RandomAccessRead input, int firstByte) {
    final buffer = StringBuffer()
      ..writeCharCode(firstByte);
    var byte = input.read();
    while (byte != -1 && byte != 0x0d && byte != 0x0a) {
      buffer.writeCharCode(byte);
      byte = input.read();
    }
    return buffer.toString();
  }

  _LiteralName _readLiteralName(RandomAccessRead input) {
    final buffer = StringBuffer();
    var byte = input.read();
    while (byte != -1 && !_isWhitespace(byte) && !_isDelimiter(byte)) {
      buffer.writeCharCode(byte);
      byte = input.read();
    }
    if (byte != -1 && _isDelimiter(byte)) {
      input.rewind(1);
    }
    return _LiteralName(buffer.toString());
  }

  _Operator _readOperator(RandomAccessRead input, int initial) {
    final buffer = StringBuffer()
      ..writeCharCode(initial);
    var byte = input.read();
    while (byte != -1 && !_isWhitespace(byte) && !_isDelimiter(byte) && !_isDigit(byte)) {
      buffer.writeCharCode(byte);
      byte = input.read();
    }
    if (byte != -1 && (_isDelimiter(byte) || _isDigit(byte))) {
      input.rewind(1);
    }
    return _Operator(buffer.toString());
  }

  num _readNumber(RandomAccessRead input, int initial) {
    final buffer = StringBuffer()
      ..writeCharCode(initial);
    var byte = input.read();
    while (byte != -1 && !_isWhitespace(byte) && (_isDigit(byte) || byte == 0x2e)) {
      buffer.writeCharCode(byte);
      byte = input.read();
    }
    if (byte != -1) {
      input.rewind(1);
    }
    final value = buffer.toString();
    if (value.contains('.')) {
      return double.parse(value);
    }
    return int.parse(value);
  }

  Object _readDictionaryOrHex(RandomAccessRead input) {
    final next = input.read();
    if (next == 0x3c) {
      final map = <String, Object>{};
      var key = _parseNextToken(input);
      while (key is _LiteralName && key.value != _markEndOfDictionary) {
        final value = _parseNextToken(input);
        map[key.value] = value!;
        key = _parseNextToken(input);
      }
      return map;
    }

    var byte = next;
    var multiplier = 16;
    var bufferIndex = -1;
    while (byte != -1 && byte != 0x3e) {
      if (_isWhitespace(byte)) {
        byte = input.read();
        continue;
      }
      final value = _hexValue(byte);
      if (value == -1) {
        throw FormatException('Expected hex digit, got ${String.fromCharCode(byte)}');
      }
      var entry = value * multiplier;
      if (multiplier == 16) {
        bufferIndex++;
        if (bufferIndex >= _tokenBuffer.length) {
          throw FormatException('CMap token larger than buffer size ${_tokenBuffer.length}');
        }
        _tokenBuffer[bufferIndex] = 0;
        multiplier = 1;
      } else {
        multiplier = 16;
      }
      _tokenBuffer[bufferIndex] += entry;
      byte = input.read();
    }
    return Uint8List.fromList(_tokenBuffer.sublist(0, bufferIndex + 1));
  }

  String _createStringFromBytes(Uint8List bytes) {
    if (bytes.length <= 2) {
      final mapping = CMapStrings.getMapping(bytes);
      if (mapping != null) {
        return mapping;
      }
      return String.fromCharCodes(bytes);
    }
    final codeUnits = List<int>.generate(bytes.length ~/ 2, (index) {
      final high = bytes[index * 2] & 0xff;
      final low = bytes[index * 2 + 1] & 0xff;
      return (high << 8) | low;
    });
    return String.fromCharCodes(codeUnits);
  }

  bool _increment(Uint8List data, int position, bool strictMode) {
    if (position > 0 && data[position] == 0xff) {
      if (strictMode) {
        return false;
      }
      data[position] = 0;
      return _increment(data, position - 1, strictMode);
    }
    data[position] = (data[position] + 1) & 0xff;
    return true;
  }

  bool _arraysEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  bool _isWhitespace(int value) {
    return value == 0x20 || value == 0x09 || value == 0x0d || value == 0x0a;
  }

  bool _isDelimiter(int value) {
    switch (value) {
      case 0x28: // (
      case 0x29: // )
      case 0x3c: // <
      case 0x3e: // >
      case 0x5b: // [
      case 0x5d: // ]
      case 0x7b: // {
      case 0x7d: // }
      case 0x2f: // /
      case 0x25: // %
        return true;
      default:
        return false;
    }
  }

  bool _isDigit(int value) => value >= 0x30 && value <= 0x39;

  int _hexValue(int byte) {
    if (byte >= 0x30 && byte <= 0x39) {
      return byte - 0x30;
    }
    if (byte >= 0x41 && byte <= 0x46) {
      return 10 + byte - 0x41;
    }
    if (byte >= 0x61 && byte <= 0x66) {
      return 10 + byte - 0x61;
    }
    return -1;
  }
}

class _LiteralName {
  _LiteralName(this.value);
  final String value;
}

class _Operator {
  _Operator(this.name);
  final String name;
}
