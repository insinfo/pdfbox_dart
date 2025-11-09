import 'dart:typed_data';

import '../../io/exceptions.dart';
import '../cos/cos_dictionary.dart';
import 'decode_options.dart';
import 'decode_result.dart';
import 'filter.dart';
import 'filter_decode_result.dart';

class ASCIIHexFilter extends Filter {
  const ASCIIHexFilter();

  static const int _eod = 0x3E; // '>'
  static final Uint8List _hexDigits =
      Uint8List.fromList('0123456789ABCDEF'.codeUnits);

  @override
  FilterDecodeResult decode(
    Uint8List encoded,
    COSDictionary parameters,
    int index, {
    DecodeOptions options = DecodeOptions.defaultOptions,
  }) {
    final output = BytesBuilder(copy: false);
    int? highNibble;

    for (final byte in encoded) {
      final int ch = byte & 0xFF;
      if (_isWhitespace(ch)) {
        continue;
      }
      if (ch == _eod) {
        break;
      }
      final int value = _hexValue(ch);
      if (value == -1) {
        throw IOException(
          'Invalid data in /ASCIIHexDecode stream: 0x${ch.toRadixString(16)}',
        );
      }
      if (highNibble == null) {
        highNibble = value;
      } else {
        output.addByte((highNibble << 4) | value);
        highNibble = null;
      }
    }

    if (highNibble != null) {
      output.addByte(highNibble << 4);
    }

    return FilterDecodeResult(
      output.takeBytes(),
      DecodeResult(parameters),
    );
  }

  @override
  Uint8List encode(Uint8List input, COSDictionary parameters, int index) {
    final output = BytesBuilder(copy: false);
    for (final byte in input) {
      output.addByte(_hexDigits[byte >> 4]);
      output.addByte(_hexDigits[byte & 0x0F]);
    }
    output.addByte(_eod);
    return output.takeBytes();
  }

  static bool _isWhitespace(int ch) {
    switch (ch) {
      case 0:
      case 9:
      case 10:
      case 12:
      case 13:
      case 32:
        return true;
      default:
        return false;
    }
  }

  static int _hexValue(int ch) {
    if (ch >= 0x30 && ch <= 0x39) {
      return ch - 0x30;
    }
    if (ch >= 0x41 && ch <= 0x46) {
      return ch - 0x41 + 10;
    }
    if (ch >= 0x61 && ch <= 0x66) {
      return ch - 0x61 + 10;
    }
    return -1;
  }
}
