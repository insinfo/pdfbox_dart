/// Helper that mimics PDFBox's EndstreamFilterStream behaviour.
///
/// It tracks trailing CR/LF sequences so the calculated stream length
/// matches PDFBox's lenient handling of inline stream endings.
class EndstreamFilterStream {
  bool _hasCR = false;
  bool _hasLF = false;
  int _position = 0;
  bool _mustFilter = true;
  int _length = 0;

  /// Updates the filtered length for [length] bytes from [buffer] starting at [offset].
  void filter(List<int> buffer, int offset, int length) {
    if (length <= 0) {
      return;
    }
    if (_position == 0 && length > 10) {
      _mustFilter = !_looksAscii(buffer, offset);
    }

    var effectiveLength = length;
    if (_mustFilter) {
      if (_hasCR) {
        _hasCR = false;
        if (!_hasLF && effectiveLength == 1 && buffer[offset] == 0x0a) {
          return;
        }
        _length++;
      }
      if (_hasLF) {
        _length++;
        _hasLF = false;
      }
      if (effectiveLength > 0) {
        final lastIndex = offset + effectiveLength - 1;
        final lastByte = buffer[lastIndex];
        if (lastByte == 0x0d) {
          _hasCR = true;
          effectiveLength--;
        } else if (lastByte == 0x0a) {
          _hasLF = true;
          effectiveLength--;
          if (effectiveLength > 0 &&
              buffer[offset + effectiveLength - 1] == 0x0d) {
            _hasCR = true;
            effectiveLength--;
          }
        }
      }
    }

    _length += effectiveLength;
    _position += effectiveLength;
  }

  /// Finalises any buffered CR/LF bytes and returns the filtered length.
  int calculateLength() {
    if (_hasCR && !_hasLF) {
      _length++;
      _position++;
    }
    _hasCR = false;
    _hasLF = false;
    return _length;
  }

  bool _looksAscii(List<int> buffer, int offset) {
    for (var i = 0; i < 10; ++i) {
      final value = buffer[offset + i];
      if ((value < 0x09) ||
          ((value > 0x0a) && (value < 0x20) && (value != 0x0d))) {
        return false;
      }
    }
    return true;
  }
}
