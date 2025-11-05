

library lzw_core;

import "dart:async" show Stream;
import "dart:collection" show HashMap;
import "dart:convert" show ByteConversionSink, ChunkedConversionSink, Converter;
import "dart:typed_data" show Uint8List;

part "src/buffer.dart";
part "src/codec.dart";
part "src/encoder.dart";
part "src/decoder.dart";
part "src/reader.dart";
part "src/writer.dart";

/**
 * LZW options.
 */
class LzwOptions {
  final int minCodeLen;
  final int maxCodeLen;
  final bool lsb;
  final bool blockMode;
  final bool clear;
  final bool end;
  final bool earlyChange;

  /**
   * Codes in the dictionary will be as minimum [minCodeLen] bits
   * maximum [maxCodeLen] bits.
   *
   * If [lsb] is true, the "Least Significant Bit first" packing order will
   * be used. If [lsb] is false, the "Most Significant Bit first" packing
   * order will be used.
   *
   * If [blockMode] is true, a "Clear Table" marker will be used to indicate
   * that the dictionary should be cleared.
   *
   * If [clear] is true, a "Clear" marker should be the first encoded symbol.
   *
   * If [end] is true, an "End Of Data" marker should be the last encoded symbol.
   *
   * If [earlyChange] is true, code length increases shall occur one code
   * early. If [earlyChange] is false, code length increases shall be
   * postponed as long as possible.
   */
  const LzwOptions({
    this.minCodeLen = 9,
    this.maxCodeLen = 12,
    this.lsb = true,
    this.blockMode = true,
    this.clear = false,
    this.end = true,
    this.earlyChange = false,
  });
}
