import 'dart:typed_data';

/// Represents a single entry in a CMap codespace range.
class CodespaceRange {
  CodespaceRange(Uint8List startBytes, Uint8List endBytes)
      : _codeLength = endBytes.length,
        _start = List<int>.filled(endBytes.length, 0),
        _end = List<int>.filled(endBytes.length, 0) {
    Uint8List correctedStart = startBytes;
    if (startBytes.length != endBytes.length) {
      if (startBytes.length == 1 && startBytes[0] == 0) {
        correctedStart = Uint8List(endBytes.length);
      } else {
        throw ArgumentError('Start and end values must have equal length.');
      }
    }
    for (var i = 0; i < correctedStart.length; i++) {
      _start[i] = correctedStart[i] & 0xff;
      _end[i] = endBytes[i] & 0xff;
    }
  }

  final List<int> _start;
  final List<int> _end;
  final int _codeLength;

  int get codeLength => _codeLength;

  bool matches(Uint8List code) => isFullMatch(code, code.length);

  bool isFullMatch(Uint8List code, int codeLen) {
    if (codeLen != _codeLength) {
      return false;
    }
    for (var i = 0; i < _codeLength; i++) {
      final value = code[i] & 0xff;
      if (value < _start[i] || value > _end[i]) {
        return false;
      }
    }
    return true;
  }
}
