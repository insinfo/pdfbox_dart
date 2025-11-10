import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../../../io/closeable.dart';
import '../../../../io/random_access_read.dart';
import '../../../../io/random_access_read_buffer.dart';
import '../../../../io/random_access_read_buffered_file.dart';
import '../../../cos/cos_document.dart';
import '../../../pdfparser/cos_parser.dart';

/// Options that control how a digital signature is applied to a document.
class SignatureOptions implements Closeable {
  SignatureOptions();

  /// Default signature size used by PDFBox.
  static const int defaultSignatureSize = 0x2500;

  COSDocument? _visualSignature;
  RandomAccessRead? _pdfSource;
  int _preferredSignatureSize = 0;
  int _page = 0;

  /// The 0-based page index where the signature appearance should be placed.
  int get page => _page;

  set page(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'page', 'Page index must be non-negative');
    }
    _page = value;
  }

  /// Convenience wrapper mirroring the PDFBox API.
  void setPage(int value) => page = value;

  /// Returns the parsed visual signature document, if any.
  COSDocument? get visualSignature => _visualSignature;

  /// Preferred signature size in bytes. `0` means “use the default”.
  int get preferredSignatureSize => _preferredSignatureSize;

  /// Updates the preferred signature size. Values <= 0 are ignored.
  void setPreferredSignatureSize(int size) {
    if (size > 0) {
      _preferredSignatureSize = size;
    }
  }

  /// Parses a visual signature from [file].
  void setVisualSignatureFromFile(File file) {
    final source = RandomAccessReadBufferedFile.fromFile(file);
    _initFromRandomAccessRead(source);
  }

  /// Parses a visual signature from the provided [data].
  void setVisualSignatureFromBytes(Uint8List data) {
    final source = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(data));
    _initFromRandomAccessRead(source);
  }

  /// Parses a visual signature from a byte [stream].
  Future<void> setVisualSignatureFromStream(Stream<List<int>> stream,
      {int chunkSize = RandomAccessReadBuffer.defaultChunkSize4KB}) async {
    final buffer =
        await RandomAccessReadBuffer.createBufferFromStream(stream, chunkSize: chunkSize);
    _initFromRandomAccessRead(buffer);
  }

  void _initFromRandomAccessRead(RandomAccessRead source) {
    _disposeCurrent();
    try {
      final parser = COSParser(source);
      final document = parser.parseDocument();
      _visualSignature = document;
      _pdfSource = source;
    } catch (_) {
      try {
        source.close();
      } catch (_) {
        // ignore close failure during parse error cleanup
      }
      rethrow;
    }
  }

  void _disposeCurrent() {
    final currentDocument = _visualSignature;
    if (currentDocument != null && !currentDocument.isClosed) {
      try {
        currentDocument.close();
      } catch (_) {
        // ignore failures while disposing
      }
    }
    _visualSignature = null;

    final source = _pdfSource;
    if (source != null && !source.isClosed) {
      try {
        source.close();
      } catch (_) {
        // ignore failures while disposing
      }
    }
    _pdfSource = null;
  }

  @override
  void close() {
    _disposeCurrent();
  }
}