import 'dart:typed_data';

import 'byte_input_buffer.dart';

/// Bit-level reader that wraps a [ByteInputBuffer] with JPEG 2000 bit-stuffing support.
class ByteToBitInput {
  ByteToBitInput(this._input);

  final ByteInputBuffer _input;
  int _bitBuffer = 0;
  int _bitPosition = -1;

  /// Reads one bit from the stream, applying bit unstuffing rules.
  int readBit() {
    if (_bitPosition < 0) {
      if ((_bitBuffer & 0xFF) != 0xFF) {
        _bitBuffer = _input.read();
        _bitPosition = 7;
      } else {
        _bitBuffer = _input.read();
        _bitPosition = 6;
      }
    }
    return (_bitBuffer >> _bitPosition--) & 0x01;
  }

  /// Verifies the remaining padding bits follow the alternating 0/1 pattern.
  bool checkBytePadding() {
    if (_bitPosition < 0 && (_bitBuffer & 0xFF) == 0xFF) {
      _bitBuffer = _input.read();
      _bitPosition = 6;
    }

    if (_bitPosition >= 0) {
      final remainingMask = (1 << (_bitPosition + 1)) - 1;
      final sequence = _bitBuffer & remainingMask;
      if (sequence != (0x55 >> (7 - _bitPosition))) {
        return true;
      }
    }

    if (_bitBuffer != -1) {
      if (_bitBuffer == 0xFF && _bitPosition == 0) {
        final next = _input.read();
        if (next >= 0 && next >= 0x80) {
          return true;
        }
      } else {
        if (_input.read() != -1) {
          return true;
        }
      }
    }

    return false;
  }

  /// Clears the bit buffer so the next read starts on a byte boundary.
  void flush() {
    _bitBuffer = 0;
    _bitPosition = -1;
  }

  /// Resets the underlying byte buffer to a new segment.
  void setByteArray(Uint8List? buffer, int offset, int length) {
    _input.setByteArray(buffer, offset, length);
    _bitBuffer = 0;
    _bitPosition = -1;
  }
}
