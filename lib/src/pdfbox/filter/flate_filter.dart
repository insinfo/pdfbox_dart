import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../io/exceptions.dart';
import '../cos/cos_dictionary.dart';
import 'decode_options.dart';
import 'decode_result.dart';
import 'filter.dart';
import 'filter_decode_result.dart';
import 'predictor.dart';

class FlateFilter extends Filter {
  const FlateFilter();

  @override
  FilterDecodeResult decode(
    Uint8List encoded,
    COSDictionary parameters,
    int index, {
    DecodeOptions options = DecodeOptions.defaultOptions,
  }) {
    final decodeParams = getDecodeParams(parameters, index);
    try {
      final decodedBytes = Uint8List.fromList(
        ZLibDecoder().decodeBytes(encoded, verify: false),
      );
      final predicted = Predictor.apply(decodedBytes, decodeParams);
      return FilterDecodeResult(predicted, DecodeResult(parameters));
    } catch (error) {
      throw IOException('Failed to decode /Flate data - $error');
    }
  }

  @override
  Uint8List encode(Uint8List input, COSDictionary parameters, int index) {
    try {
      return Uint8List.fromList(ZLibEncoder().encode(input));
    } catch (error) {
      throw IOException('Failed to encode /Flate data - $error');
    }
  }

  @override
  int getCompressionLevel() => -1;
}
