import 'dart:async';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read.dart';

import 'ttf_data_stream.dart';

class RandomAccessReadUnbufferedDataStream extends TtfDataStream {
  RandomAccessReadUnbufferedDataStream(this._source)
      : _length = _source.length;

  final RandomAccessRead _source;
  final int _length;

  @override
  void close() {
    _source.close();
  }

  @override
  int read() {
    return _source.read();
  }

  @override
  int readLong() {
    final high = _readInt();
    final low = _readInt();
    return ((high & 0xffffffff) << 32) | (low & 0xffffffff);
  }

  int _readInt() {
    final b1 = readUnsignedByte();
    final b2 = readUnsignedByte();
    final b3 = readUnsignedByte();
    final b4 = readUnsignedByte();
    return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
  }

  @override
  void seek(int position) {
    _source.seek(position);
  }

  @override
  int readInto(Uint8List buffer, int offset, int length) {
    return _source.readBuffer(buffer, offset, length);
  }

  @override
  int get currentPosition => _source.position;

  @override
  RandomAccessRead? createSubView(int length) {
    try {
      return _source.createView(_source.position, length);
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<List<int>> openOriginalDataStream() async* {
    final view = _tryCreateFullView();
    if (view != null) {
      final buffer = Uint8List(4096);
      while (true) {
        final read = view.readBuffer(buffer);
        if (read <= 0) {
          break;
        }
        yield buffer.sublist(0, read);
      }
      view.close();
      return;
    }

    // fallback: copy entire content without altering cursor
    final current = _source.position;
    try {
      _source.seek(0);
      final buffer = Uint8List(4096);
      while (true) {
        final read = _source.readBuffer(buffer);
        if (read <= 0) {
          break;
        }
        yield buffer.sublist(0, read);
      }
    } finally {
      _source.seek(current);
    }
  }

  RandomAccessRead? _tryCreateFullView() {
    try {
      return _source.createView(0, _length);
    } catch (_) {
      return null;
    }
  }

  @override
  int get originalDataSize => _length;
}
