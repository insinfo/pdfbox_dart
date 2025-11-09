import 'dart:typed_data';

import 'decode_result.dart';

class FilterDecodeResult {
  FilterDecodeResult(this.data, this.decodeResult);

  final Uint8List data;
  final DecodeResult decodeResult;
}
