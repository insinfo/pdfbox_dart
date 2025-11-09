import 'dart:typed_data';

import '../../io/exceptions.dart';
import '../cos/cos_dictionary.dart';
import 'decode_options.dart';
import 'decode_result.dart';
import 'filter.dart';
import 'filter_decode_result.dart';

class ASCII85Filter extends Filter {
  const ASCII85Filter();

  static const int _offset = 0x21; // '!'
  static const int _terminator = 0x7E; // '~'
  static const int _eod = 0x3E; // '>'
  static const int _padding = 0x75; // 'u'
  static const int _z = 0x7A; // 'z'

  @override
  FilterDecodeResult decode(
    Uint8List encoded,
    COSDictionary parameters,
    int index, {
    DecodeOptions options = DecodeOptions.defaultOptions,
  }) {
    final output = BytesBuilder(copy: false);
    final ascii = List<int>.filled(5, 0);
    var asciiIndex = 0;

    for (var i = 0; i < encoded.length; i++) {
      final int ch = encoded[i] & 0xFF;
      if (_isWhitespace(ch)) {
        continue;
      }
      if (ch == _terminator) {
        break;
      }
      if (ch == _z) {
        if (asciiIndex != 0) {
          throw IOException(
            'Invalid data in /ASCII85Decode stream: unexpected "z" inside group',
          );
        }
        output.add(const <int>[0, 0, 0, 0]);
        continue;
      }
      final int value = ch - _offset;
      if (value < 0 || value > 84) {
        throw IOException(
          'Invalid data in /ASCII85Decode stream: 0x${ch.toRadixString(16)}',
        );
      }
      ascii[asciiIndex++] = ch;
      if (asciiIndex == 5) {
        output.add(_decodeTuple(ascii));
        asciiIndex = 0;
      }
    }

    if (asciiIndex > 0) {
      for (var j = asciiIndex; j < 5; j++) {
        ascii[j] = _padding;
      }
      final chunk = _decodeTuple(ascii);
      final bytesToWrite = asciiIndex - 1;
      if (bytesToWrite > 0) {
        output.add(chunk.sublist(0, bytesToWrite));
      }
    }

    return FilterDecodeResult(
      output.takeBytes(),
      DecodeResult(parameters),
    );
  }

  @override
  Uint8List encode(Uint8List input, COSDictionary parameters, int index) {
    final output = BytesBuilder(copy: false);
    var offset = 0;

    while (offset + 4 <= input.length) {
      final value = _wordFromBytes(input, offset);
      if (value == 0) {
        output.addByte(_z);
      } else {
        output.add(_encodeWord(value));
      }
      offset += 4;
    }

    final remaining = input.length - offset;
    if (remaining > 0) {
      var value = 0;
      for (var i = 0; i < 4; i++) {
        value <<= 8;
        if (i < remaining) {
          value |= input[offset + i];
        }
      }
      final chunk = _encodeWord(value);
      output.add(chunk.sublist(0, remaining + 1));
    }

    output.addByte(_terminator);
    output.addByte(_eod);
    return output.takeBytes();
  }

  static Uint8List _decodeTuple(List<int> ascii) {
    var value = 0;
    for (var i = 0; i < 5; i++) {
      final digit = ascii[i] - _offset;
      if (digit < 0 || digit > 84) {
        throw IOException(
          'Invalid data in /ASCII85Decode stream: 0x${ascii[i].toRadixString(16)}',
        );
      }
      value = (value * 85) + digit;
    }
    final result = Uint8List(4);
    for (var i = 3; i >= 0; i--) {
      result[i] = value & 0xFF;
      value >>= 8;
    }
    return result;
  }

  static List<int> _encodeWord(int value) {
    final digits = List<int>.filled(5, 0);
    for (var i = 4; i >= 0; i--) {
      digits[i] = (value % 85) + _offset;
      value ~/= 85;
    }
    return digits;
  }

  static int _wordFromBytes(Uint8List input, int index) {
    var value = 0;
    for (var i = 0; i < 4; i++) {
      value = (value << 8) | input[index + i];
    }
    return value;
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
}
