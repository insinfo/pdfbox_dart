
library lzw;

import "dart:convert" show Codec, Converter;
import "lzw_core.dart" show LzwEncoder, LzwDecoder, LzwOptions;

export "lzw_core.dart" show LzwOptions;

/**
 * An instance of the default implementation of the [LzwCodec].
 *
 * This instance provides a convenient access to the most common LZW use cases.
 */
const LzwCodec LZW = const LzwCodec();

/**
 * The [LzwCodec] encodes raw bytes to LZW compressed bytes and decodes LZW
 * compressed bytes to raw bytes.
 */
class LzwCodec extends Codec<List<int>, List<int>> {
  final LzwOptions options;

  /**
   * Construct a new [LzwCodec] with default options.
   *
   * An instance of [LzwOptions] could be created to use a custom set
   * of options.
   */
  const LzwCodec([this.options = const LzwOptions()]);

  /**
   * Encodes raw bytes to LZW compressed bytes.
   */
  List<int> encode(List<int> input)
    => new LzwEncoder(options).convertSlice(input, 0, input.length, true);

  /**
   * Decodes LZW compressed bytes to raw bytes.
   */
  List<int> decode(List<int> encoded)
    => new LzwDecoder(options).convertSlice(encoded, 0, encoded.length, true);

  /**
   * Get a [Converter] for encoding to LZW compressed data.
   *
   * It is stateful and must not be reused.
   */
  Converter<List<int>, List<int>> get encoder => new LzwEncoder(options);

  /**
   * Get a [Converter] for decoding LZW compressed data.
   *
   * It is stateful and must not be reused.
   */
  Converter<List<int>, List<int>> get decoder => new LzwDecoder(options);
}
