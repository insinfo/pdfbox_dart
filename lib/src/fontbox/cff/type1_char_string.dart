import 'package:logging/logging.dart';

import '../encoding/standard_encoding.dart';
import '../type1/type1_char_string_reader.dart';
import '../util/bounding_box.dart';
import 'char_string_command.dart';
import 'char_string_path.dart';

/// Represents and renders a Type 1 CharString program.
class Type1CharString {
  Type1CharString(
    Type1CharStringReader font,
    String fontName,
    String glyphName,
    List<Object> sequence,
  )   : _font = font,
        _fontName = fontName,
        _glyphName = glyphName,
        _current = _Point(0, 0) {
    _type1Sequence.addAll(sequence);
  }

  Type1CharString.base(
    Type1CharStringReader font,
    String fontName,
    String glyphName,
  )   : _font = font,
        _fontName = fontName,
        _glyphName = glyphName,
        _current = _Point(0, 0);

  static final Logger _log = Logger('fontbox.Type1CharString');

  final Type1CharStringReader _font;
  final String _fontName;
  final String _glyphName;

  CharStringPath? _path;
  double _width = 0;
  _Point _current;
  _Point _leftSideBearing = _Point(0, 0);
  bool _isFlex = false;
  final List<_Point> _flexPoints = <_Point>[];
  final List<Object> _type1Sequence = <Object>[];
  int _commandCount = 0;

  /// Returns the glyph name associated with this charstring.
  String get name => _glyphName;

  /// Returns the bounding box for the rendered outline.
  BoundingBox getBounds() {
    final path = getPath();
    return path.getBounds();
  }

  /// Returns the advance width of the glyph.
  double getWidth() {
    getPath();
    return _width;
  }

  /// Returns the vector outline associated with this charstring.
  CharStringPath getPath() {
    var path = _path;
    if (path != null) {
      return path;
    }
    path = CharStringPath();
    _path = path;
    _leftSideBearing = _Point(0, 0);
    _width = 0;
    _current = _Point(0, 0);
    _flexPoints.clear();
    _isFlex = false;

    final numbers = <num>[];
    for (final entry in _type1Sequence) {
      if (entry is CharStringCommand) {
        _handleCommand(numbers, entry);
      } else if (entry is num) {
        numbers.add(entry);
      }
    }
    return path;
  }

  void _handleCommand(List<num> numbers, CharStringCommand command) {
    _commandCount++;
    final keyword = command.type1KeyWord;
    if (keyword == null) {
      _log.warning(
        () => 'Unknown charstring command in glyph $_glyphName of font $_fontName',
      );
      numbers.clear();
      return;
    }

    switch (keyword) {
      case Type1KeyWord.rmoveto:
        if (numbers.length >= 2) {
          if (_isFlex) {
            _flexPoints.add(_Point(numbers[0].toDouble(), numbers[1].toDouble()));
          } else {
            _rmoveTo(numbers[0], numbers[1]);
          }
        }
        break;
      case Type1KeyWord.vmoveto:
        if (numbers.isNotEmpty) {
          if (_isFlex) {
            _flexPoints.add(_Point(0, numbers[0].toDouble()));
          } else {
            _rmoveTo(0, numbers[0]);
          }
        }
        break;
      case Type1KeyWord.hmoveto:
        if (numbers.isNotEmpty) {
          if (_isFlex) {
            _flexPoints.add(_Point(numbers[0].toDouble(), 0));
          } else {
            _rmoveTo(numbers[0], 0);
          }
        }
        break;
      case Type1KeyWord.rlineto:
        if (numbers.length >= 2) {
          _rlineTo(numbers[0], numbers[1]);
        }
        break;
      case Type1KeyWord.hlineto:
        if (numbers.isNotEmpty) {
          _rlineTo(numbers[0], 0);
        }
        break;
      case Type1KeyWord.vlineto:
        if (numbers.isNotEmpty) {
          _rlineTo(0, numbers[0]);
        }
        break;
      case Type1KeyWord.rrcurveto:
        if (numbers.length >= 6) {
          _rrcurveTo(numbers[0], numbers[1], numbers[2], numbers[3], numbers[4], numbers[5]);
        }
        break;
      case Type1KeyWord.closepath:
        _closePath();
        break;
      case Type1KeyWord.sbw:
        if (numbers.length >= 3) {
          _leftSideBearing = _Point(numbers[0].toDouble(), numbers[1].toDouble());
          _width = numbers[2].toDouble();
          _current = _Point(_leftSideBearing.x, _leftSideBearing.y);
        }
        break;
      case Type1KeyWord.hsbw:
        if (numbers.length >= 2) {
          _leftSideBearing = _Point(numbers[0].toDouble(), 0);
          _width = numbers[1].toDouble();
          _current = _Point(_leftSideBearing.x, _leftSideBearing.y);
        }
        break;
      case Type1KeyWord.vhcurveto:
        if (numbers.length >= 4) {
          _rrcurveTo(0, numbers[0], numbers[1], numbers[2], numbers[3], 0);
        }
        break;
      case Type1KeyWord.hvcurveto:
        if (numbers.length >= 4) {
          _rrcurveTo(numbers[0], 0, numbers[1], numbers[2], 0, numbers[3]);
        }
        break;
      case Type1KeyWord.seac:
        if (numbers.length >= 5) {
          _seac(numbers[0], numbers[1], numbers[2], numbers[3], numbers[4]);
        }
        break;
      case Type1KeyWord.setcurrentpoint:
        if (numbers.length >= 2) {
          _setCurrentPoint(numbers[0], numbers[1]);
        }
        break;
      case Type1KeyWord.callothersubr:
        if (numbers.isNotEmpty) {
          _callOtherSubr(numbers[0].toInt());
        }
        break;
      case Type1KeyWord.div:
        if (numbers.length >= 2) {
          final b = numbers.removeLast().toDouble();
          final a = numbers.removeLast().toDouble();
          numbers.add(a / b);
          return;
        }
        break;
      case Type1KeyWord.hstem:
      case Type1KeyWord.vstem:
      case Type1KeyWord.hstem3:
      case Type1KeyWord.vstem3:
      case Type1KeyWord.dotsection:
      case Type1KeyWord.endchar:
        break;
      case Type1KeyWord.ret:
      case Type1KeyWord.callsubr:
        _log.warning(
          () => 'Unexpected charstring command: $keyword in glyph $_glyphName of font $_fontName',
        );
        break;
      default:
        throw ArgumentError('Unhandled command: $keyword');
    }
    numbers.clear();
  }

  void _setCurrentPoint(num x, num y) {
    _current = _Point(x.toDouble(), y.toDouble());
  }

  void _callOtherSubr(int num) {
    if (num == 0) {
      _isFlex = false;
      if (_flexPoints.length < 7) {
        _log.warning(() =>
            'flex without moveTo in font $_fontName, glyph $_glyphName, command $_commandCount');
        _flexPoints.clear();
        return;
      }

      final reference = _flexPoints[0];
      reference.translate(_current.x, _current.y);

      final first = _flexPoints[1];
      first.translate(reference.x, reference.y);
      first.translate(-_current.x, -_current.y);

      final p1 = _flexPoints[1];
      final p2 = _flexPoints[2];
      final p3 = _flexPoints[3];
      _rrcurveTo(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);

      final p4 = _flexPoints[4];
      final p5 = _flexPoints[5];
      final p6 = _flexPoints[6];
      _rrcurveTo(p4.x, p4.y, p5.x, p5.y, p6.x, p6.y);
      _flexPoints.clear();
    } else if (num == 1) {
      _isFlex = true;
    } else {
      _log.warning(() => 'Invalid callothersubr parameter: $num');
    }
  }

  void _rmoveTo(num dx, num dy) {
    final x = _current.x + dx.toDouble();
    final y = _current.y + dy.toDouble();
    _path!.moveTo(x, y);
    _current = _Point(x, y);
  }

  void _rlineTo(num dx, num dy) {
    final x = _current.x + dx.toDouble();
    final y = _current.y + dy.toDouble();
    final path = _path!;
    if (!path.hasCurrentPoint) {
      _log.warning(() => 'rlineTo without initial moveTo in font $_fontName, glyph $_glyphName');
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
    _current = _Point(x, y);
  }

  void _rrcurveTo(num dx1, num dy1, num dx2, num dy2, num dx3, num dy3) {
    final x1 = _current.x + dx1.toDouble();
    final y1 = _current.y + dy1.toDouble();
    final x2 = x1 + dx2.toDouble();
    final y2 = y1 + dy2.toDouble();
    final x3 = x2 + dx3.toDouble();
    final y3 = y2 + dy3.toDouble();
    final path = _path!;
    if (!path.hasCurrentPoint) {
      _log.warning(() => 'rrcurveTo without initial moveTo in font $_fontName, glyph $_glyphName');
      path.moveTo(x3, y3);
    } else {
      path.curveTo(x1, y1, x2, y2, x3, y3);
    }
    _current = _Point(x3, y3);
  }

  void _closePath() {
    final path = _path!;
    if (!path.hasCurrentPoint) {
      _log.warning(() => 'closepath without initial moveTo in font $_fontName, glyph $_glyphName');
    } else {
      path.closePath();
    }
    path.moveTo(_current.x, _current.y);
  }

  void _seac(num asb, num adx, num ady, num bchar, num achar) {
    final baseName = StandardEncoding.instance.getName(bchar.toInt());
    try {
      final base = _font.getType1CharString(baseName);
      _path!.append(base.getPath());
    } catch (e, stack) {
      _log.warning(
        () => 'invalid seac character in glyph $_glyphName of font $_fontName',
        e,
        stack,
      );
    }

    final accentName = StandardEncoding.instance.getName(achar.toInt());
    try {
      final accent = _font.getType1CharString(accentName);
      final accentPath = accent.getPath();
      if (identical(_path, accentPath)) {
        _log.warning(() => 'Path for $baseName and accent $accentName are same, ignored');
        return;
      }
      final dx = _leftSideBearing.x + adx.toDouble() - asb.toDouble();
      final dy = _leftSideBearing.y + ady.toDouble();
      _path!.append(accentPath, dx: dx, dy: dy);
    } catch (e, stack) {
      _log.warning(
        () => 'invalid seac character in glyph $_glyphName of font $_fontName',
        e,
        stack,
      );
    }
  }

  /// Adds a command to the underlying Type 1 sequence.
  void addCommand(List<num> numbers, CharStringCommand command) {
    _type1Sequence.addAll(numbers);
    _type1Sequence.add(command);
  }

  /// Returns true when the recorded Type 1 sequence is empty.
  bool isSequenceEmpty() => _type1Sequence.isEmpty;

  /// Returns the last item recorded in the Type 1 sequence.
  Object? getLastSequenceEntry() => _type1Sequence.isEmpty ? null : _type1Sequence.last;

  @override
  String toString() => _type1Sequence.join(' ');
}

class _Point {
  _Point(this.x, this.y);

  double x;
  double y;

  void translate(double dx, double dy) {
    x += dx;
    y += dy;
  }
}
