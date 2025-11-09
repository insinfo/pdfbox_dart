import 'dart:math' as math;
import 'dart:typed_data';

import '../cos/cos_dictionary.dart';
import 'decode_options.dart';
import 'decode_result.dart';
import 'filter.dart';
import 'filter_decode_result.dart';

class RunLengthFilter extends Filter {
  const RunLengthFilter();

  static const int _eodMarker = 128;

  @override
  FilterDecodeResult decode(
    Uint8List encoded,
    COSDictionary parameters,
    int index, {
    DecodeOptions options = DecodeOptions.defaultOptions,
  }) {
    final output = BytesBuilder(copy: false);

    var offset = 0;
    while (offset < encoded.length) {
      final dupAmount = encoded[offset++];
      if (dupAmount == _eodMarker) {
        break;
      }
      if (dupAmount <= 127) {
        final length = dupAmount + 1;
        if (offset >= encoded.length) {
          break;
        }
        final end = math.min(offset + length, encoded.length);
        if (end > offset) {
          output.add(encoded.sublist(offset, end));
          offset = end;
        } else {
          break;
        }
      } else {
        if (offset >= encoded.length) {
          break;
        }
        final value = encoded[offset++];
        final repeatCount = 257 - dupAmount;
        final repeats = Uint8List(repeatCount);
        repeats.fillRange(0, repeatCount, value);
        output.add(repeats);
      }
    }

    final data = output.takeBytes();
    return FilterDecodeResult(data, DecodeResult(parameters));
  }

  @override
  Uint8List encode(Uint8List input, COSDictionary parameters, int index) {
    if (input.isEmpty) {
      return Uint8List.fromList(const <int>[_eodMarker]);
    }

    final encoded = BytesBuilder(copy: false);
    var lastValue = -1;
    var count = 0;
    var equality = false;
    final unequalBuffer = Uint8List(128);

    for (final byt in input) {
      if (lastValue == -1) {
        lastValue = byt;
        count = 1;
        continue;
      }

      if (count == 128) {
        if (equality) {
          encoded.add(<int>[129, lastValue]);
        } else {
          encoded.add(<int>[127]);
          encoded.add(unequalBuffer.sublist(0, 128));
        }
        equality = false;
        lastValue = byt;
        count = 1;
        continue;
      }

      if (count == 1) {
        if (byt == lastValue) {
          equality = true;
        } else {
          unequalBuffer[0] = lastValue;
          unequalBuffer[1] = byt;
          equality = false;
        }
        lastValue = byt;
        count = 2;
        continue;
      }

      if (byt == lastValue) {
        if (equality) {
          count++;
        } else {
          encoded.add(<int>[count - 2]);
          encoded.add(unequalBuffer.sublist(0, count - 1));
          count = 2;
          equality = true;
        }
      } else {
        if (equality) {
          encoded.add(<int>[257 - count, lastValue]);
          equality = false;
          count = 1;
        } else {
          unequalBuffer[count] = byt;
          count++;
        }
        lastValue = byt;
      }
    }

    if (count > 0) {
      if (count == 1) {
        encoded.add(<int>[0, lastValue]);
      } else if (equality) {
        encoded.add(<int>[257 - count, lastValue]);
      } else {
        encoded.add(<int>[count - 1]);
        encoded.add(unequalBuffer.sublist(0, count));
      }
    }

    encoded.add(const <int>[_eodMarker]);

    return encoded.takeBytes();
  }
}
