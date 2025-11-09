import 'dart:typed_data';

import '../../dependencies/lzw/lzw.dart';
import '../../io/exceptions.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import 'decode_options.dart';
import 'decode_result.dart';
import 'filter.dart';
import 'filter_decode_result.dart';
import 'predictor.dart';

class LZWFilter extends Filter {
  const LZWFilter();

  static const int _minCodeLength = 9;
  static const int _maxCodeLength = 12;

  LzwOptions _options({required bool earlyChange, required bool emitClear}) {
    return LzwOptions(
      minCodeLen: _minCodeLength,
      maxCodeLen: _maxCodeLength,
      lsb: false,
      blockMode: true,
      clear: emitClear,
      end: true,
      earlyChange: earlyChange,
    );
  }

  @override
  FilterDecodeResult decode(
    Uint8List encoded,
    COSDictionary parameters,
    int index, {
    DecodeOptions options = DecodeOptions.defaultOptions,
  }) {
    final decodeParams = getDecodeParams(parameters, index);
    final bool earlyChange =
        (decodeParams.getInt(COSName.earlyChange, 1) ?? 1) != 0;

    try {
      final codec = LzwCodec(_options(earlyChange: earlyChange, emitClear: false));
      final decodedBytes = Uint8List.fromList(codec.decode(encoded));
      final predicted = Predictor.apply(decodedBytes, decodeParams);
      return FilterDecodeResult(predicted, DecodeResult(parameters));
    } on IOException {
      rethrow;
    } catch (error) {
      throw IOException('Failed to decode /LZW data - $error');
    }
  }

  @override
  Uint8List encode(Uint8List input, COSDictionary parameters, int index) {
    final decodeParams = getDecodeParams(parameters, index);
    final bool earlyChange =
        (decodeParams.getInt(COSName.earlyChange, 1) ?? 1) != 0;

    try {
      final codec = LzwCodec(_options(earlyChange: earlyChange, emitClear: true));
      return Uint8List.fromList(codec.encode(input));
    } on IOException {
      rethrow;
    } catch (error) {
      throw IOException('Failed to encode /LZW data - $error');
    }
  }
}
