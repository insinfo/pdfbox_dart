import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../io/exceptions.dart';
import '../cos/cos_dictionary.dart';
import 'decode_options.dart';
import 'decode_result.dart';
import 'filter.dart';
import 'filter_decode_result.dart';

class DCTFilter extends Filter {
  const DCTFilter();

  @override
  FilterDecodeResult decode(
    Uint8List encoded,
    COSDictionary parameters,
    int index, {
    DecodeOptions options = DecodeOptions.defaultOptions,
  }) {
    try {
      final decoder = img.JpegDecoder();
      final img.Image? image = decoder.decode(encoded);
      if (image == null) {
        throw IOException('Failed to decode JPEG stream.');
      }
      final preserveRaw = options.preserveRawDct;
      final originalChannels = image.numChannels;
      final Uint8List data;
      if (preserveRaw) {
        data = image.getBytes();
      } else {
        data = image.getBytes(order: img.ChannelOrder.rgba, alpha: 255);
      }
      final colorInfo = JpegColorInfo(
        width: image.width,
        height: image.height,
        originalChannelCount: originalChannels,
        outputChannelCount: preserveRaw ? originalChannels : 4,
        possibleCmyk: originalChannels == 4,
        convertedToRgba: !preserveRaw,
      );
      return FilterDecodeResult(
        data,
        DecodeResult(parameters, colorSpace: colorInfo),
      );
    } on IOException {
      rethrow;
    } catch (error) {
      throw IOException('Failed to decode /DCT data - $error');
    }
  }

  @override
  Uint8List encode(Uint8List input, COSDictionary parameters, int index) {
    throw IOException('Encoding /DCT data is not supported.');
  }
}

/// Metadata describing the colour processing applied to a decoded JPEG stream.
class JpegColorInfo {
  const JpegColorInfo({
    required this.width,
    required this.height,
    required this.originalChannelCount,
    required this.outputChannelCount,
    required this.possibleCmyk,
    required this.convertedToRgba,
  });

  final int width;
  final int height;
  final int originalChannelCount;
  final int outputChannelCount;
  final bool possibleCmyk;
  final bool convertedToRgba;
}
