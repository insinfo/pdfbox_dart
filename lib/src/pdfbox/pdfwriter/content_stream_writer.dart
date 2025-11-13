import 'dart:convert';
import 'dart:typed_data';

import '../../io/random_access_write.dart';
import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_boolean.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_integer.dart';
import '../cos/cos_name.dart';
import '../cos/cos_null.dart';
import '../cos/cos_number.dart';
import '../cos/cos_object.dart';
import '../cos/cos_string.dart';
import '../contentstream/operator/operator.dart';
import '../contentstream/operator/operator_name.dart';

/// Writes a sequence of content stream tokens to a [RandomAccessWrite].
class ContentStreamWriter {
  ContentStreamWriter(this._output);

  static final Uint8List _space = Uint8List.fromList(<int>[0x20]);
  static final Uint8List _eol = Uint8List.fromList(<int>[0x0a]);

  final RandomAccessWrite _output;

  void writeToken(COSBase base) => _writeCOSObject(base);

  void writeOperator(Operator operator) => _writeOperator(operator);

  void writeTokens(Iterable<Object?> tokens, {bool appendLineFeed = false}) {
    for (final token in tokens) {
      _writeObject(token);
    }
    if (appendLineFeed) {
      _writeEol();
    }
  }

  void writeTokensWithNewline(List<Object?> tokens) =>
      writeTokens(tokens, appendLineFeed: true);

  void _writeObject(Object? token) {
    if (token is COSBase) {
      _writeCOSObject(token);
    } else if (token is Operator) {
      _writeOperator(token);
    } else if (token != null) {
      throw ArgumentError.value(token, 'token',
          'Unsupported type ${token.runtimeType} in content stream');
    }
  }

  void _writeOperator(Operator operator) {
    final name = operator.name;
    if (name == OperatorName.beginInlineImage) {
      _writeAscii(name);
      _writeEol();

      final params = operator.imageParameters;
      if (params != null) {
        for (final entry in params.entries) {
          _writeCOSObject(entry.key, topLevel: true);
          _writeSpace();
          _writeCOSObject(entry.value);
          _writeEol();
        }
      }

      _writeAscii(OperatorName.beginInlineImageData);
      _writeEol();
      final imageData = operator.imageData;
      if (imageData != null && imageData.isNotEmpty) {
        _output.writeBytes(imageData);
        _writeEol();
      }
      _writeAscii(OperatorName.endInlineImage);
      _writeEol();
    } else {
      _writeAscii(name);
      _writeEol();
    }
  }

  void _writeCOSObject(COSBase object, {bool topLevel = false}) {
    if (object is COSString) {
      _writeAscii(object.isHex
          ? _formatHexString(object)
          : _formatLiteralString(object));
      _writeSpace();
    } else if (object is COSBoolean) {
      _writeAscii(object.value ? 'true' : 'false');
      _writeSpace();
    } else if (object is COSNumber) {
      _writeAscii(_formatNumber(object));
      _writeSpace();
    } else if (object is COSName) {
      _writeAscii(object.toString());
      _writeSpace();
    } else if (object is COSArray) {
      _writeAscii('[');
      for (final element in object) {
        _writeCOSObject(element, topLevel: false);
      }
      _writeAscii(']');
      _writeSpace();
    } else if (object is COSDictionary) {
      _writeAscii('<<');
      for (final entry in object.entries) {
        _writeCOSObject(entry.key, topLevel: true);
        _writeCOSObject(entry.value, topLevel: false);
      }
      _writeAscii('>>');
      _writeSpace();
    } else if (object is COSObject) {
      final dereferenced = object.object;
      final key = object.key;
      if (!topLevel && key != null) {
        _writeAscii('${key.objectNumber} ${key.generationNumber} R');
        _writeSpace();
      } else if (dereferenced is COSNull) {
        _writeAscii('null');
        _writeSpace();
      } else {
        _writeCOSObject(dereferenced, topLevel: topLevel);
      }
    } else if (object is COSNull) {
      _writeAscii('null');
      _writeSpace();
    } else {
      throw ArgumentError('Unsupported COS type ${object.runtimeType}');
    }
  }

  void _writeSpace() => _output.writeBytes(_space);

  void _writeEol() => _output.writeBytes(_eol);

  void _writeAscii(String value) {
    if (value.isEmpty) {
      return;
    }
    _output.writeBytes(Uint8List.fromList(latin1.encode(value)));
  }

  String _formatNumber(COSNumber number) {
    if (number is COSInteger) {
      return number.intValue.toString();
    }
    final double value = number.doubleValue;
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  String _formatLiteralString(COSString string) {
    final buffer = StringBuffer('(');
    final bytes = string.bytes;
    for (final byte in bytes) {
      switch (byte) {
        case 0x08:
          buffer.write('\\b');
          break;
        case 0x09:
          buffer.write('\\t');
          break;
        case 0x0a:
          buffer.write('\\n');
          break;
        case 0x0c:
          buffer.write('\\f');
          break;
        case 0x0d:
          buffer.write('\\r');
          break;
        case 0x28:
          buffer.write('\\(');
          break;
        case 0x29:
          buffer.write('\\)');
          break;
        case 0x5c:
          buffer.write('\\\\');
          break;
        default:
          if (byte < 0x20 || byte > 0x7e) {
            buffer
              ..write('\\')
              ..write(byte.toRadixString(8).padLeft(3, '0'));
          } else {
            buffer.writeCharCode(byte);
          }
      }
    }
    buffer.write(')');
    return buffer.toString();
  }

  String _formatHexString(COSString string) {
    final buffer = StringBuffer('<');
    for (final byte in string.bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    buffer.write('>');
    return buffer.toString().toUpperCase();
  }
}
