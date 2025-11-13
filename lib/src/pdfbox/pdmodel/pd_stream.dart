import 'dart:async';
import 'dart:typed_data';

import '../../io/random_access_read.dart';
import '../contentstream/pd_content_stream.dart';
import '../cos/cos_stream.dart';
import '../filter/decode_options.dart';
import '../filter/filter_pipeline.dart';
import '../pdfparser/pdf_stream_parser.dart';

/// High level wrapper over a COS stream used by the PD layer.
class PDStream implements PDContentStream {
  PDStream(this._stream);

  /// Creates a new PDStream with [data] as its encoded contents.
  factory PDStream.fromBytes(Uint8List data) {
    final stream = COSStream();
    stream.data = data;
    return PDStream(stream);
  }

  final COSStream _stream;

  COSStream get cosStream => _stream;

  /// Returns the encoded bytes of this stream, if available.
  Uint8List? get encodedBytes => _stream.encodedBytes();

  /// Replaces the encoded bytes stored in this stream.
  set encodedBytes(Uint8List? bytes) => _stream.data = bytes;

  /// Opens a stream of the encoded bytes without decoding filters.
  Stream<List<int>> openEncodedStream() => _stream.openStream();

  /// Returns the decoded bytes, applying filters when necessary.
  Uint8List? decode({DecodeOptions options = DecodeOptions.defaultOptions}) =>
      _stream.decode(options: options);

  /// Returns the decoded bytes together with filter metadata.
  FilterPipelineResult? decodeWithResult({
    DecodeOptions options = DecodeOptions.defaultOptions,
  }) =>
      _stream.decodeWithResult(options: options);

  @override
  RandomAccessRead getContentsForStreamParsing() {
    return _stream.createView();
  }

  /// Parses this content stream into PDF tokens using [PDFStreamParser].
  List<Object?> parseTokens() {
    final parser = PDFStreamParser(this);
    return parser.parse();
  }
}
