import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read.dart';

import 'ttf_data_stream.dart';

/// Wrapper for a single font stream inside a TrueType collection.
class TtcDataStream extends TtfDataStream {
  TtcDataStream(this._delegate);

  final TtfDataStream _delegate;

  @override
  int read() => _delegate.read();

  @override
  int readLong() => _delegate.readLong();

  @override
  void close() {
    // intentionally no-op: the underlying stream is shared by the whole collection
  }

  @override
  void seek(int position) => _delegate.seek(position);

  @override
  int readInto(Uint8List buffer, int offset, int length) =>
      _delegate.readInto(buffer, offset, length);

  @override
  int get currentPosition => _delegate.currentPosition;

  @override
  RandomAccessRead? createSubView(int length) => _delegate.createSubView(length);

  @override
  Stream<List<int>> openOriginalDataStream() => _delegate.openOriginalDataStream();

  @override
  int get originalDataSize => _delegate.originalDataSize;
}
