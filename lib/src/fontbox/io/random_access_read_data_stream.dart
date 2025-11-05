import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/random_access_read.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';

import 'ttf_data_stream.dart';

final Logger _logRandomAccessReadDataStream =
    Logger('fontbox.RandomAccessReadDataStream');

class RandomAccessReadDataStream extends TtfDataStream {
  RandomAccessReadDataStream.fromRandomAccessRead(RandomAccessRead source)
      : this.fromData(_readAll(source));

  RandomAccessReadDataStream.fromData(Uint8List data)
      : _data = Uint8List.view(data.buffer, data.offsetInBytes, data.length),
        _length = data.length,
        _currentPosition = 0;

  static Uint8List _readAll(RandomAccessRead source) {
    final totalLength = source.length;
    if (totalLength < 0) {
      throw IOException('Unknown source length');
    }
    if (totalLength > 0x7fffffff) {
      throw IOException('Stream is too long, size: $totalLength');
    }
    final buffer = Uint8List(totalLength);
    var offset = 0;
    while (offset < totalLength) {
      final read = source.readBuffer(buffer, offset, totalLength - offset);
      if (read <= 0) {
        break;
      }
      offset += read;
    }
    if (offset != totalLength) {
      throw IOException('Could not read entire stream, expected $totalLength bytes, got $offset');
    }
    return buffer;
  }

  final Uint8List _data;
  final int _length;
  int _currentPosition;

  @override
  void close() {}

  @override
  int read() {
    if (_currentPosition >= _length) {
      return -1;
    }
    return _data[_currentPosition++] & 0xff;
  }

  @override
  int readLong() {
    return ((readInt() & 0xffffffff) << 32) | (readInt() & 0xffffffff);
  }

  int readInt() {
    final b1 = readUnsignedByte();
    final b2 = readUnsignedByte();
    final b3 = readUnsignedByte();
    final b4 = readUnsignedByte();
    return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
  }

  @override
  void seek(int position) {
    if (position < 0) {
      throw IOException('Invalid position $position');
    }
    _currentPosition = position <= _length ? position : _length;
  }

  @override
  int readInto(Uint8List buffer, int offset, int length) {
    if (length <= 0) {
      return 0;
    }
    if (_currentPosition >= _length) {
      return -1;
    }
    final remaining = _length - _currentPosition;
    final bytesToRead = remaining < length ? remaining : length;
    buffer.setRange(
      offset,
      offset + bytesToRead,
      Uint8List.view(_data.buffer, _data.offsetInBytes + _currentPosition, bytesToRead),
    );
    _currentPosition += bytesToRead;
    return bytesToRead;
  }

  @override
  int get currentPosition => _currentPosition;

  @override
  RandomAccessRead? createSubView(int length) {
    try {
      final buffer = RandomAccessReadBuffer.fromBytes(_data);
      return buffer.createView(_currentPosition, length);
    } catch (e, stackTrace) {
      _logRandomAccessReadDataStream.warning(
        'Could not create a sub view',
        e,
        stackTrace,
      );
      return null;
    }
  }

  @override
  Stream<List<int>> openOriginalDataStream() async* {
    yield _data;
  }

  @override
  int get originalDataSize => _length;
}
