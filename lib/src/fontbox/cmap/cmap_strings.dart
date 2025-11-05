import 'dart:typed_data';

class CMapStrings {
  CMapStrings._();

  static final List<String> _twoByteMappings = _createTwoByteMappings();
  static final List<String> _oneByteMappings = _createOneByteMappings();

  static final List<int> _indexValues = List<int>.generate(256 * 256, (index) => index);
  static final List<Uint8List> _oneByteValues =
      List<Uint8List>.generate(256, (value) => Uint8List.fromList(<int>[value]));
  static final List<Uint8List> _twoByteValues = List<Uint8List>.generate(
    256 * 256,
    (index) => Uint8List.fromList(<int>[index >> 8, index & 0xff]),
  );

  static String? getMapping(Uint8List bytes) {
    if (bytes.length > 2) {
      return null;
    }
    final index = _toInt(bytes);
    return bytes.length == 1 ? _oneByteMappings[index] : _twoByteMappings[index];
  }

  static int? getIndexValue(Uint8List bytes) {
    if (bytes.length > 2) {
      return null;
    }
    return _indexValues[_toInt(bytes)];
  }

  static Uint8List? getByteValue(Uint8List bytes) {
    if (bytes.length > 2) {
      return null;
    }
    final index = _toInt(bytes);
    return bytes.length == 1 ? _oneByteValues[index] : _twoByteValues[index];
  }

  static List<String> _createTwoByteMappings() {
    return List<String>.generate(256 * 256, (index) {
      final codePoint = (index >> 8) << 8 | (index & 0xff);
      return String.fromCharCode(codePoint);
    }, growable: false);
  }

  static List<String> _createOneByteMappings() {
    return List<String>.generate(256, (index) {
      return String.fromCharCode(index);
    }, growable: false);
  }

  static int _toInt(Uint8List bytes) {
    var value = 0;
    for (final byte in bytes) {
      value = (value << 8) | (byte & 0xff);
    }
    return value;
  }
}
