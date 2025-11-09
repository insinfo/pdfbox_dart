import 'dart:typed_data';

import '../cos/cos_stream.dart';
import '../filter/decode_result.dart';

/// Holds the encoded and decoded representations of a COS stream as seen by the parser.
class ParsedStream {
  const ParsedStream({
    required this.stream,
    this.encoded,
    this.decoded,
    this.decodeResults = const <DecodeResult>[],
  });

  final COSStream stream;
  final Uint8List? encoded;
  final Uint8List? decoded;
  final List<DecodeResult> decodeResults;

  bool get hasDecoded => decoded != null;

  DecodeResult? get lastDecodeResult =>
      decodeResults.isEmpty ? null : decodeResults.last;
}
