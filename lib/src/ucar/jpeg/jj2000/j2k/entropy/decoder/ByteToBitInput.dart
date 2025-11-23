import 'dart:typed_data';

import 'ByteInputBuffer.dart';

/// Bit-level reader that wraps a [ByteInputBuffer] with JPEG 2000 bit-stuffing support.
class ByteToBitInput {
  ByteToBitInput(this._input);

  final ByteInputBuffer _input;
  int _bitBuffer = 0;
  int _bitPosition = -1;
  int _pendingByte = -1;

  /// Reads one bit from the stream, applying bit unstuffing rules.
  int readBit() {
    if (_bitPosition < 0) {
      _bitBuffer = _readNextDataByte(previousWasMarker: (_bitBuffer & 0xFF) == 0xFF);
      _bitPosition = 7;
    }
    return (_bitBuffer >> _bitPosition--) & 0x01;
  }

  /// Reads the next byte, skipping stuffed zero bytes inserted after 0xFF.
  int readByte() {
    if (_bitPosition >= 0) {
      var value = 0;
      for (var bit = 7; bit >= 0; bit--) {
        value |= (readBit() & 0x01) << bit;
      }
      _bitBuffer = 0;
      _bitPosition = -1;
      return value & 0xFF;
    }

    final value = _takeByteFromSource();
    if (value < 0) {
      return value;
    }
    if (value != 0xFF) {
      return value;
    }

    final next = _takeByteFromSource();
    if (next < 0) {
      return 0xFF;
    }
    if (next == 0x00) {
      return 0xFF;
    }
    _pendingByte = next;
    return 0xFF;
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
    _pendingByte = -1;
  }

  /// Resets the underlying byte buffer to a new segment.
  void setByteArray(Uint8List? buffer, int offset, int length) {
    _input.setByteArray(buffer, offset, length);
    _bitBuffer = 0;
    _bitPosition = -1;
    _pendingByte = -1;
  }

  int _readNextDataByte({required bool previousWasMarker}) {
    if (!previousWasMarker) {
      final value = _takeByteFromSource();
      return value < 0 ? 0 : value;
    }

    final stuffed = _takeByteFromSource();
    if (stuffed == 0x00) {
      final value = _takeByteFromSource();
      return value < 0 ? 0 : value;
    }
    if (stuffed == -1) {
      return 0;
    }
    return stuffed;
  }

  int _takeByteFromSource() {
    if (_pendingByte >= 0) {
      final value = _pendingByte;
      _pendingByte = -1;
      return value;
    }
    return _input.read();
  }
}

