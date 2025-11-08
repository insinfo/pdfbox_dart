import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import 'char_string_command.dart';
import 'data_input.dart';
import 'data_input_byte_array.dart';

/// Converts Type 1 CharString bytecode into a token sequence.
class Type1CharStringParser {
  Type1CharStringParser(this._fontName);

  static final Logger _log = Logger('fontbox.Type1CharStringParser');

  final String _fontName;
  String _currentGlyph = '';

  static const int _callsubr = 10;
  static const int _twoByte = 12;
  static const int _callothersubr = 16;
  static const int _pop = 17;

  /// Parses [bytes] into a Type 1 CharString sequence.
  List<Object> parse(Uint8List bytes, List<Uint8List> subrs, String glyphName) {
    _currentGlyph = glyphName;
    return _parse(bytes, subrs, <Object>[]);
  }

  List<Object> _parse(Uint8List bytes, List<Uint8List> subrs, List<Object> sequence) {
    final input = DataInputByteArray(bytes);
    while (input.hasRemaining()) {
      final b0 = input.readUnsignedByte();
      if (b0 == _callsubr) {
        _processCallSubr(subrs, sequence);
      } else if (b0 == _twoByte && input.peekUnsignedByte(0) == _callothersubr) {
        _processCallOtherSubr(input, sequence);
      } else if (b0 >= 0 && b0 <= 31) {
        sequence.add(_readCommand(input, b0));
      } else if (b0 >= 32 && b0 <= 255) {
        sequence.add(_readNumber(input, b0));
      } else {
        throw IOException('Invalid Type 1 charstring byte $b0');
      }
    }
    return sequence;
  }

  void _processCallSubr(List<Uint8List> subrs, List<Object> sequence) {
    if (sequence.isEmpty) {
      _log.warning(() =>
          'CALLSUBR encountered without operand in glyph "$_currentGlyph" of font $_fontName');
      return;
    }
    final obj = sequence.removeLast();
    if (obj is! int) {
      _log.warning(() =>
          'Parameter $obj for CALLSUBR is ignored, integer expected in glyph "$_currentGlyph" of font $_fontName');
      return;
    }
    final operand = obj;
    if (operand >= 0 && operand < subrs.length) {
      final subrBytes = subrs[operand];
      _parse(subrBytes, subrs, sequence);
      if (sequence.isNotEmpty) {
        final last = sequence.last;
        if (last is CharStringCommand && last.type1KeyWord == Type1KeyWord.ret) {
          sequence.removeLast();
        }
      }
    } else {
      _log.warning(() =>
          'CALLSUBR is ignored, operand: $operand, subrs.size(): ${subrs.length} in glyph "$_currentGlyph" of font $_fontName');
      while (sequence.isNotEmpty && sequence.last is int) {
        sequence.removeLast();
      }
    }
  }

  void _processCallOtherSubr(DataInput input, List<Object> sequence) {
    input.readByte();

    final othersubrNum = sequence.isNotEmpty ? sequence.removeLast() : null;
    final numArgs = sequence.isNotEmpty ? sequence.removeLast() : null;

    if (othersubrNum is! int || numArgs is! int) {
      _log.warning(() =>
          'Malformed callothersubr in glyph "$_currentGlyph" of font $_fontName');
      return;
    }

    final results = <int>[];
    switch (othersubrNum) {
      case 0:
        results.add(_removeInteger(sequence));
        results.add(_removeInteger(sequence));
        if (sequence.isNotEmpty) {
          sequence.removeLast();
        }
        sequence.add(0);
        sequence.add(CharStringCommand.callothersubr);
        break;
      case 1:
        sequence.add(1);
        sequence.add(CharStringCommand.callothersubr);
        break;
      case 3:
        results.add(_removeInteger(sequence));
        break;
      default:
        for (var i = 0; i < numArgs; i++) {
          results.add(_removeInteger(sequence));
        }
        break;
    }

    while (input.peekUnsignedByte(0) == _twoByte && input.peekUnsignedByte(1) == _pop) {
      input.readByte();
      input.readByte();
      if (results.isEmpty) {
        _log.warning(() =>
            'Value expected on PostScript stack in glyph "$_currentGlyph" of font $_fontName');
        break;
      }
      sequence.add(results.removeLast());
    }

    if (results.isNotEmpty) {
      _log.warning(() =>
          'Value left on the PostScript stack in glyph "$_currentGlyph" of font $_fontName');
    }
  }

  int _removeInteger(List<Object> sequence) {
    if (sequence.isEmpty) {
      throw IOException('Operand stack underflow in glyph "$_currentGlyph" of font $_fontName');
    }
    final item = sequence.removeLast();
    if (item is int) {
      return item;
    }
    if (item is CharStringCommand && item.type1KeyWord == Type1KeyWord.div) {
      final a = _removeInteger(sequence);
      final b = _removeInteger(sequence);
      return (b / a).truncate();
    }
    throw IOException('Unexpected char string command: $item');
  }

  CharStringCommand _readCommand(DataInput input, int b0) {
    if (b0 == _twoByte) {
      final b1 = input.readUnsignedByte();
      return CharStringCommand.fromEscapedByte(b1);
    }
    return CharStringCommand.fromByte(b0);
  }

  int _readNumber(DataInput input, int b0) {
    if (b0 >= 32 && b0 <= 246) {
      return b0 - 139;
    }
    if (b0 >= 247 && b0 <= 250) {
      final b1 = input.readUnsignedByte();
      return (b0 - 247) * 256 + b1 + 108;
    }
    if (b0 >= 251 && b0 <= 254) {
      final b1 = input.readUnsignedByte();
      return -(b0 - 251) * 256 - b1 - 108;
    }
    if (b0 == 255) {
      return input.readInt();
    }
    throw IOException('Invalid number byte $b0 in glyph "$_currentGlyph" of font $_fontName');
  }
}
