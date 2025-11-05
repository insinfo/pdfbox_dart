import 'dart:typed_data';

/// Range of continuous CIDs between two code points.
class CidRange {
  CidRange(this._from, this._to, this._cidStart, this._codeLength);

  final int _from;
  int _to;
  final int _cidStart;
  final int _codeLength;

  int get codeLength => _codeLength;

  int mapBytes(Uint8List bytes) {
    if (bytes.length == _codeLength) {
  final code = _toInt(bytes);
      if (_from <= code && code <= _to) {
        return _cidStart + (code - _from);
      }
    }
    return -1;
  }

  int mapCode(int code, int length) {
    if (length == _codeLength && _from <= code && code <= _to) {
      return _cidStart + (code - _from);
    }
    return -1;
  }

  int unmap(int cid) {
    if (_cidStart <= cid && cid <= _cidStart + (_to - _from)) {
      return _from + (cid - _cidStart);
    }
    return -1;
  }

  bool extend(int newFrom, int newTo, int newCid, int length) {
    if (_codeLength == length && newFrom == _to + 1 && newCid == _cidStart + _to - _from + 1) {
      _to = newTo;
      return true;
    }
    return false;
  }
}

int _toInt(Uint8List data) {
  var code = 0;
  for (final value in data) {
    code = (code << 8) | (value & 0xff);
  }
  return code;
}
