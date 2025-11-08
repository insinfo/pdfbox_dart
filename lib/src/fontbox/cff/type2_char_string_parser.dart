import 'dart:typed_data';

import '../../io/exceptions.dart';
import 'char_string_command.dart';
import 'data_input.dart';
import 'data_input_byte_array.dart';

/// Expands Type 2 charstrings into a token sequence resolving subroutines and masks.
class Type2CharStringParser {
  Type2CharStringParser(this._fontName);

  final String _fontName;

  static const int _callsubr = 10;
  static const int _callgsubr = 29;
  static const int _hintmask = 19;
  static const int _cntrmask = 20;

  /// Decodes [bytes] into a sequence of operands and [CharStringCommand] tokens.
  List<Object> parse(
    Uint8List bytes,
    List<Uint8List> globalSubrIndex,
    List<Uint8List> localSubrIndex,
  ) {
    final glyphData = _GlyphData();
    _parseSequence(bytes, globalSubrIndex, localSubrIndex, glyphData);
    return glyphData.sequence;
  }

  void _parseSequence(
    Uint8List bytes,
    List<Uint8List> globalSubrIndex,
    List<Uint8List> localSubrIndex,
    _GlyphData glyphData,
  ) {
    final input = DataInputByteArray(bytes);

    while (input.hasRemaining()) {
      final b0 = input.readUnsignedByte();
      if (b0 == _callsubr) {
        _processCallSubr(globalSubrIndex, localSubrIndex, glyphData);
      } else if (b0 == _callgsubr) {
        _processCallGSubr(globalSubrIndex, localSubrIndex, glyphData);
      } else if (b0 == _hintmask || b0 == _cntrmask) {
        glyphData.vstemCount += _countNumbers(glyphData.sequence) ~/ 2;
        final maskLength = _getMaskLength(glyphData.hstemCount, glyphData.vstemCount);
        for (var i = 0; i < maskLength; i++) {
          input.readUnsignedByte();
        }
        glyphData.sequence.add(CharStringCommand.fromByte(b0));
      } else if ((b0 >= 0 && b0 <= 18) || (b0 >= 21 && b0 <= 27) || (b0 >= 29 && b0 <= 31)) {
        glyphData.sequence.add(_readCommand(b0, input, glyphData));
      } else if (b0 == 28 || (b0 >= 32 && b0 <= 255)) {
        glyphData.sequence.add(_readNumber(b0, input));
      } else {
        throw IOException('Illegal Type 2 charstring byte $b0 in font $_fontName');
      }
    }
  }

  void _processCallSubr(
    List<Uint8List> globalSubrIndex,
    List<Uint8List> localSubrIndex,
    _GlyphData glyphData,
  ) {
    if (localSubrIndex.isEmpty) {
      return;
    }
    final subrBytes = _getSubrBytes(localSubrIndex, glyphData);
    _processSubr(globalSubrIndex, localSubrIndex, subrBytes, glyphData);
  }

  void _processCallGSubr(
    List<Uint8List> globalSubrIndex,
    List<Uint8List> localSubrIndex,
    _GlyphData glyphData,
  ) {
    if (globalSubrIndex.isEmpty) {
      return;
    }
    final subrBytes = _getSubrBytes(globalSubrIndex, glyphData);
    _processSubr(globalSubrIndex, localSubrIndex, subrBytes, glyphData);
  }

  void _processSubr(
    List<Uint8List> globalSubrIndex,
    List<Uint8List> localSubrIndex,
    Uint8List? subrBytes,
    _GlyphData glyphData,
  ) {
    if (subrBytes == null) {
      return;
    }
    _parseSequence(subrBytes, globalSubrIndex, localSubrIndex, glyphData);
    if (glyphData.sequence.isNotEmpty) {
      final last = glyphData.sequence.last;
      if (last is CharStringCommand && last.type2KeyWord == Type2KeyWord.ret) {
        glyphData.sequence.removeLast();
      }
    }
  }

  Uint8List? _getSubrBytes(List<Uint8List> subrIndex, _GlyphData glyphData) {
    if (glyphData.sequence.isEmpty) {
      return null;
    }
    final last = glyphData.sequence.removeLast();
    if (last is! num) {
      glyphData.sequence.add(last);
      return null;
    }
    final operand = last.toInt();
    final subrNumber = _calculateSubrNumber(operand, subrIndex.length);
    if (subrNumber >= 0 && subrNumber < subrIndex.length) {
      return subrIndex[subrNumber];
    }
    return null;
  }

  int _calculateSubrNumber(int operand, int length) {
    if (length < 1240) {
      return 107 + operand;
    }
    if (length < 33900) {
      return 1131 + operand;
    }
    return 32768 + operand;
  }

  CharStringCommand _readCommand(int b0, DataInput input, _GlyphData glyphData) {
    switch (b0) {
      case 1:
      case 18:
        glyphData.hstemCount += _countNumbers(glyphData.sequence) ~/ 2;
        return CharStringCommand.fromByte(b0);
      case 3:
      case 23:
        glyphData.vstemCount += _countNumbers(glyphData.sequence) ~/ 2;
        return CharStringCommand.fromByte(b0);
      case 12:
        final b1 = input.readUnsignedByte();
        return CharStringCommand.fromEscapedByte(b1);
      default:
        return CharStringCommand.fromByte(b0);
    }
  }

  num _readNumber(int b0, DataInput input) {
    if (b0 == 28) {
      return input.readShort();
    }
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
      final value = input.readShort();
      final fraction = input.readUnsignedShort() / 65535.0;
      return value + fraction;
    }
    throw IOException('Invalid number byte $b0 in font $_fontName');
  }

  int _getMaskLength(int hstemCount, int vstemCount) {
    final hintCount = hstemCount + vstemCount;
    final length = hintCount ~/ 8;
    return (hintCount % 8) > 0 ? length + 1 : length;
  }

  int _countNumbers(List<Object> sequence) {
    var count = 0;
    for (var i = sequence.length - 1; i >= 0; i--) {
      if (sequence[i] is! num) {
        return count;
      }
      count++;
    }
    return count;
  }
}

class _GlyphData {
  final List<Object> sequence = <Object>[];
  int hstemCount = 0;
  int vstemCount = 0;
}
