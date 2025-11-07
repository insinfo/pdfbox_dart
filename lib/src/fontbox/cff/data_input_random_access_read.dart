import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/random_access_read.dart';

import 'data_input.dart';

/// Implementação de [DataInput] que usa um [RandomAccessRead] como origem.
class DataInputRandomAccessRead implements DataInput {
  DataInputRandomAccessRead(this._source);

  final RandomAccessRead _source;

  @override
  bool hasRemaining() => _source.available() > 0;

  @override
  int getPosition() => _source.position;

  @override
  void setPosition(int position) {
    if (position < 0) {
      throw IOException('position is negative');
    }
    if (position > _source.length) {
      throw IOException('New position is out of range $position >= ${_source.length}');
    }
    _source.seek(position);
  }

  @override
  int readByte() {
    final value = _source.read();
    if (value < 0) {
      throw EofException('End of buffer reached');
    }
    return value >= 0x80 ? value - 0x100 : value;
  }

  @override
  int readUnsignedByte() {
    final value = _source.read();
    if (value < 0) {
      throw EofException('End of buffer reached');
    }
    return value;
  }

  @override
  int peekUnsignedByte(int offset) {
    if (offset < 0) {
      throw IOException('offset is negative');
    }
    if (offset == 0) {
      final value = _source.peek();
      if (value < 0) {
        throw EofException('End of buffer reached');
      }
      return value;
    }
    final current = _source.position;
    final target = current + offset;
    if (target >= _source.length) {
      throw IOException('Offset position is out of range $target >= ${_source.length}');
    }
    _source.seek(target);
    final value = _source.read();
    _source.seek(current);
    if (value < 0) {
      throw EofException('End of buffer reached');
    }
    return value;
  }

  @override
  Uint8List readBytes(int length) {
    if (length < 0) {
      throw IOException('length is negative');
    }
    final buffer = Uint8List(length);
    _source.readFully(buffer);
    return buffer;
  }

  @override
  int length() => _source.length;
}
