import '../type1/type1_char_string_reader.dart';
import 'char_string_command.dart';
import 'type1_char_string.dart';

/// Converts a Type 2 charstring program into an equivalent Type 1 representation.
class Type2CharString extends Type1CharString {
  Type2CharString(
    Type1CharStringReader font,
    String fontName,
    String glyphName,
    this.gid,
    List<Object> sequence,
    int defaultWidthX,
    int nominalWidthX,
  )   : _defWidthX = defaultWidthX.toDouble(),
        _nominalWidthX = nominalWidthX.toDouble(),
        super.base(font, fontName, glyphName) {
    _convertType2ToType1(sequence);
  }

  final double _defWidthX;
  final double _nominalWidthX;
  final int gid;
  int _pathCount = 0;

  /// Returns the glyph identifier associated with this charstring.
  int get gidValue => gid;

  void _convertType2ToType1(List<Object> sequence) {
    _pathCount = 0;

    final newSequence = <Object>[];
    for (var i = 0; i < sequence.length; i++) {
      final obj = sequence[i];
      if (obj == CharStringCommand.div && i >= 2) {
        final numerator = sequence[i - 2];
        final denominator = sequence[i - 1];
        if (numerator is num && denominator is num && newSequence.length >= 2) {
          newSequence.removeLast();
          newSequence.removeLast();
          newSequence.add(numerator.toDouble() / denominator.toDouble());
        } else {
          newSequence.add(obj);
        }
      } else {
        newSequence.add(obj);
      }
    }

    final numbers = <num>[];
    for (final obj in newSequence) {
      if (obj is CharStringCommand) {
        final results = _convertType2Command(numbers, obj);
        numbers
          ..clear()
          ..addAll(results);
      } else if (obj is num) {
        numbers.add(obj);
      }
    }
  }

  List<num> _convertType2Command(List<num> numbers, CharStringCommand command) {
    final keyword = command.type2KeyWord;
    if (keyword == null) {
      addCommand(numbers, command);
      return const <num>[];
    }

    switch (keyword) {
      case Type2KeyWord.hstem:
      case Type2KeyWord.hstemhm:
      case Type2KeyWord.vstem:
      case Type2KeyWord.vstemhm:
      case Type2KeyWord.hintmask:
      case Type2KeyWord.cntrmask:
        numbers = _clearStack(numbers, numbers.length.isOdd);
        _expandStemHints(numbers, keyword == Type2KeyWord.hstem || keyword == Type2KeyWord.hstemhm);
        break;
      case Type2KeyWord.hmoveto:
      case Type2KeyWord.vmoveto:
        numbers = _clearStack(numbers, numbers.length > 1);
        _markPath();
        addCommand(numbers, command);
        break;
      case Type2KeyWord.rlineto:
        _addCommandList(_split(numbers, 2), command);
        break;
      case Type2KeyWord.hlineto:
      case Type2KeyWord.vlineto:
        _addAlternatingLine(numbers, keyword == Type2KeyWord.hlineto);
        break;
      case Type2KeyWord.rrcurveto:
        _addCommandList(_split(numbers, 6), command);
        break;
      case Type2KeyWord.endchar:
        numbers = _clearStack(numbers, numbers.length == 5 || numbers.length == 1);
        _closeCharString2Path();
        if (numbers.length == 4) {
          addCommand(<num>[0, 0, ...numbers], CharStringCommand.seac);
        } else {
          addCommand(numbers, command);
        }
        break;
      case Type2KeyWord.rmoveto:
        numbers = _clearStack(numbers, numbers.length > 2);
        _markPath();
        addCommand(numbers, command);
        break;
      case Type2KeyWord.hvcurveto:
      case Type2KeyWord.vhcurveto:
        _addAlternatingCurve(numbers, keyword == Type2KeyWord.hvcurveto);
        break;
      case Type2KeyWord.hflex:
        if (numbers.length >= 7) {
          final first = <num>[numbers[0], 0, numbers[1], numbers[2], numbers[3], 0];
          final second = <num>[numbers[4], 0, numbers[5], -numbers[2], numbers[6], 0];
          _addCommandList(<List<num>>[first, second], CharStringCommand.rrcurveto);
        }
        break;
      case Type2KeyWord.flex:
        if (numbers.length >= 12) {
          final first = numbers.sublist(0, 6);
          final second = numbers.sublist(6, 12);
          _addCommandList(<List<num>>[first, second], CharStringCommand.rrcurveto);
        }
        break;
      case Type2KeyWord.hflex1:
        if (numbers.length >= 9) {
          final first = <num>[numbers[0], numbers[1], numbers[2], numbers[3], numbers[4], 0];
          final second = <num>[numbers[5], 0, numbers[6], numbers[7], numbers[8], 0];
          _addCommandList(<List<num>>[first, second], CharStringCommand.rrcurveto);
        }
        break;
      case Type2KeyWord.flex1:
        if (numbers.length >= 11) {
          var dx = 0;
          var dy = 0;
          for (var i = 0; i < 5; i++) {
            dx += numbers[i * 2].toInt();
            dy += numbers[i * 2 + 1].toInt();
          }
          final first = numbers.sublist(0, 6);
          final dxIsBigger = dx.abs() > dy.abs();
          final second = <num>[
            numbers[6],
            numbers[7],
            numbers[8],
            numbers[9],
            dxIsBigger ? numbers[10] : -dx,
            dxIsBigger ? -dy : numbers[10],
          ];
          _addCommandList(<List<num>>[first, second], CharStringCommand.rrcurveto);
        }
        break;
      case Type2KeyWord.rcurveline:
        if (numbers.length >= 2) {
          final curvePart = numbers.sublist(0, numbers.length - 2);
          if (curvePart.isNotEmpty) {
            _addCommandList(_split(curvePart, 6), CharStringCommand.rrcurveto);
          }
          final linePart = numbers.sublist(numbers.length - 2);
          addCommand(linePart, CharStringCommand.rlineto);
        }
        break;
      case Type2KeyWord.rlinecurve:
        if (numbers.length >= 6) {
          final linePart = numbers.sublist(0, numbers.length - 6);
          if (linePart.isNotEmpty) {
            _addCommandList(_split(linePart, 2), CharStringCommand.rlineto);
          }
          final curvePart = numbers.sublist(numbers.length - 6);
          addCommand(curvePart, CharStringCommand.rrcurveto);
        }
        break;
      case Type2KeyWord.hhcurveto:
      case Type2KeyWord.vvcurveto:
        _addCurve(numbers, keyword == Type2KeyWord.hhcurveto);
        break;
      default:
        addCommand(numbers, command);
        break;
    }
    return const <num>[];
  }

  List<num> _clearStack(List<num> numbers, bool flag) {
    if (isSequenceEmpty()) {
      if (flag && numbers.isNotEmpty) {
        addCommand(<num>[0, numbers[0].toDouble() + _nominalWidthX], CharStringCommand.hsbw);
        return numbers.sublist(1);
      } else {
        addCommand(<num>[0, _defWidthX], CharStringCommand.hsbw);
      }
    }
    return numbers;
  }

  void _expandStemHints(List<num> _numbers, bool _horizontal) {
    // Stem hints are ignored here because they do not affect outline reconstruction.
  }

  void _markPath() {
    if (_pathCount > 0) {
      _closeCharString2Path();
    }
    _pathCount++;
  }

  void _closeCharString2Path() {
    if (_pathCount == 0) {
      return;
    }
    final last = getLastSequenceEntry();
    final lastCommand = last is CharStringCommand ? last : null;
    if (lastCommand != null && lastCommand.type1KeyWord != Type1KeyWord.closepath) {
      addCommand(const <num>[], CharStringCommand.closepath);
    }
  }

  void _addAlternatingLine(List<num> numbers, bool horizontal) {
    for (final value in numbers) {
      addCommand(<num>[value], horizontal ? CharStringCommand.hlineto : CharStringCommand.vlineto);
      horizontal = !horizontal;
    }
  }

  void _addAlternatingCurve(List<num> numbers, bool horizontal) {
    var index = 0;
    while (numbers.length - index >= 4) {
      final remaining = numbers.length - index;
      final last = remaining == 5;
      if (horizontal) {
        final args = <num>[
          numbers[index],
          0,
          numbers[index + 1],
          numbers[index + 2],
          last ? numbers[index + 4] : 0,
          numbers[index + 3],
        ];
        addCommand(args, CharStringCommand.rrcurveto);
      } else {
        final args = <num>[
          0,
          numbers[index],
          numbers[index + 1],
          numbers[index + 2],
          numbers[index + 3],
          last ? numbers[index + 4] : 0,
        ];
        addCommand(args, CharStringCommand.rrcurveto);
      }
      index += last ? 5 : 4;
      horizontal = !horizontal;
    }
  }

  void _addCurve(List<num> numbers, bool horizontal) {
    var index = 0;
    while (numbers.length - index >= 4) {
      final remaining = numbers.length - index;
      final first = remaining % 4 == 1;
      if (horizontal) {
        final args = <num>[
          numbers[index + (first ? 1 : 0)],
          first ? numbers[index] : 0,
          numbers[index + (first ? 2 : 1)],
          numbers[index + (first ? 3 : 2)],
          numbers[index + (first ? 4 : 3)],
          0,
        ];
        addCommand(args, CharStringCommand.rrcurveto);
      } else {
        final args = <num>[
          first ? numbers[index] : 0,
          numbers[index + (first ? 1 : 0)],
          numbers[index + (first ? 2 : 1)],
          numbers[index + (first ? 3 : 2)],
          0,
          numbers[index + (first ? 4 : 3)],
        ];
        addCommand(args, CharStringCommand.rrcurveto);
      }
      index += first ? 5 : 4;
    }
  }

  void _addCommandList(List<List<num>> numbers, CharStringCommand command) {
    for (final values in numbers) {
      addCommand(values, command);
    }
  }

  List<List<num>> _split(List<num> list, int size) {
    final result = <List<num>>[];
    final listSize = list.length ~/ size;
    for (var i = 0; i < listSize; i++) {
      result.add(list.sublist(i * size, (i + 1) * size));
    }
    return result;
  }
}
