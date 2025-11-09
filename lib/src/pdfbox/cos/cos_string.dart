import 'dart:convert';
import 'dart:typed_data';

import 'cos_base.dart';

class COSString extends COSBase {
  COSString(String value) : this.fromBytes(Uint8List.fromList(utf8.encode(value)));

  COSString.fromHex(String hexString)
      : _bytes = _decodeHex(hexString),
        isHex = true;

  COSString.fromBytes(Uint8List bytes)
      : _bytes = Uint8List.fromList(bytes),
        isHex = false;

  static COSString get empty => COSString('');

  final Uint8List _bytes;
  final bool isHex;

  Uint8List get bytes => Uint8List.fromList(_bytes);

  String get string => utf8.decode(_bytes, allowMalformed: true);

  int get length => _bytes.length;

  COSString copy() => COSString.fromBytes(_bytes);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! COSString || other.length != length) {
      return false;
    }
    for (var i = 0; i < length; i++) {
      if (other._bytes[i] != _bytes[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_bytes);

  @override
  String toString() => 'COSString(${string.replaceAll('\n', '\\n')})';

  static Uint8List _decodeHex(String input) {
    final sanitized = input.replaceAll(RegExp(r'\s+'), '');
    final length = sanitized.length;
    final bytes = Uint8List((length + 1) ~/ 2);
    var byteIndex = 0;
    var i = 0;
    while (i < length) {
      final high = _hexToInt(sanitized[i]);
      final low = i + 1 < length ? _hexToInt(sanitized[i + 1]) : 0;
      bytes[byteIndex++] = (high << 4) | low;
      i += 2;
    }
    return bytes;
  }

  static int _hexToInt(String char) {
    final code = char.codeUnitAt(0);
    if (code >= 48 && code <= 57) {
      return code - 48;
    }
    if (code >= 65 && code <= 70) {
      return code - 55;
    }
    if (code >= 97 && code <= 102) {
      return code - 87;
    }
    throw FormatException('Invalid hex character: $char');
  }
}
