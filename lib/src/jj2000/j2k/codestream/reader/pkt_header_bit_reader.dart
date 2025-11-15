import 'dart:typed_data';

import '../../io/exceptions.dart';
import '../../io/random_access_io.dart';

/// Bit-level reader for JPEG 2000 packet headers with support for bit
/// unstuffing.
class PktHeaderBitReader {
  PktHeaderBitReader(RandomAccessIO input)
      : _input = input,
        _usingBuffer = false;

  PktHeaderBitReader.fromBytes(Uint8List data)
      : _buffer = data,
        _usingBuffer = true;

  RandomAccessIO? _input;
  Uint8List? _buffer;
  int _bufferPos = 0;
  bool _usingBuffer;

  int _bitBuffer = 0;
  int _bitPos = 0;
  int _nextBitBuffer = 0;

  /// Reads a single bit from the underlying source.
  int readBit() {
    if (_bitPos == 0) {
      if (_bitBuffer != 0xff) {
        _bitBuffer = _readByte();
        _bitPos = 8;
        if (_bitBuffer == 0xff) {
          _nextBitBuffer = _readByte();
        }
      } else {
        _bitBuffer = _nextBitBuffer;
        _bitPos = 7;
      }
    }
    _bitPos--;
    return (_bitBuffer >> _bitPos) & 0x01;
  }

  /// Reads [count] bits (up to 31) and returns them in the least-significant
  /// bits of the resulting integer.
  int readBits(int count) {
    if (count < 0 || count > 31) {
      throw ArgumentError.value(count, 'count', 'Must be between 0 and 31');
    }
    if (count == 0) {
      return 0;
    }
    if (count <= _bitPos) {
      _bitPos -= count;
      return (_bitBuffer >> _bitPos) & ((1 << count) - 1);
    }

    var remaining = count;
    var bits = 0;
    while (remaining > _bitPos) {
      final available = _bitPos;
      bits <<= available;
      remaining -= available;
      bits |= readBits(available);
      if (_bitBuffer != 0xff) {
        _bitBuffer = _readByte();
        _bitPos = 8;
        if (_bitBuffer == 0xff) {
          _nextBitBuffer = _readByte();
        }
      } else {
        _bitBuffer = _nextBitBuffer;
        _bitPos = 7;
      }
    }

    _bitPos -= remaining;
    bits = (bits << remaining) | ((_bitBuffer >> _bitPos) & ((1 << remaining) - 1));
    return bits;
  }

  /// Discards buffered bits and realigns with the underlying byte stream.
  void sync() {
    _bitBuffer = 0;
    _bitPos = 0;
  }

  /// Replaces the underlying source with [input], clearing buffered bits.
  void setInput(RandomAccessIO input) {
    _input = input;
    _buffer = null;
    _bufferPos = 0;
    _usingBuffer = false;
    sync();
  }

  /// Replaces the underlying source with the provided [data] buffer.
  void setInputBytes(Uint8List data) {
    _buffer = data;
    _bufferPos = 0;
    _usingBuffer = true;
    sync();
  }

  int _readByte() {
    if (_usingBuffer) {
      final source = _buffer;
      if (source == null || _bufferPos >= source.length) {
        throw EOFException('Packet header buffer exhausted');
      }
      return source[_bufferPos++] & 0xff;
    }
    final input = _input;
    if (input == null) {
      throw StateError('PktHeaderBitReader has no input source');
    }
    try {
      final value = input.read();
      return value & 0xff;
    } on EOFException {
      rethrow;
    }
  }
}
