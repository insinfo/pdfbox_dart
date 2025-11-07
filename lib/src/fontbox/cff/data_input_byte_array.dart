import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/exceptions.dart';

import 'data_input.dart';

/// Implementação de [DataInput] baseada em um [Uint8List].
class DataInputByteArray implements DataInput {
  DataInputByteArray(Uint8List buffer) : _buffer = buffer;

  final Uint8List _buffer;
  int _position = 0;

  @override
  bool hasRemaining() => _position < _buffer.length;

  @override
  int getPosition() => _position;

  @override
  void setPosition(int position) {
    if (position < 0) {
      throw IOException('position is negative');
    }
    if (position > _buffer.length) {
      throw IOException('New position is out of range $position >= ${_buffer.length}');
    }
    _position = position;
  }

  @override
  int readByte() {
    if (!hasRemaining()) {
      throw EofException('End of buffer reached');
    }
    final value = _buffer[_position++];
    return value >= 0x80 ? value - 0x100 : value;
  }

  @override
  int readUnsignedByte() {
    if (!hasRemaining()) {
      throw EofException('End of buffer reached');
    }
    return _buffer[_position++];
  }

  @override
  int peekUnsignedByte(int offset) {
    if (offset < 0) {
      throw IOException('offset is negative');
    }
    final peekIndex = _position + offset;
    if (peekIndex >= _buffer.length) {
      throw IOException('Offset position is out of range $peekIndex >= ${_buffer.length}');
    }
    return _buffer[peekIndex];
  }

  @override
  Uint8List readBytes(int length) {
    if (length < 0) {
      throw IOException('length is negative');
    }
    final remaining = _buffer.length - _position;
    if (remaining < length) {
      throw EofException('Premature end of buffer reached');
    }
    final slice = Uint8List.sublistView(_buffer, _position, _position + length);
    _position += length;
    return Uint8List.fromList(slice);
  }

  @override
  int length() => _buffer.length;
}
