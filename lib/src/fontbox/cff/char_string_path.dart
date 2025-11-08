import 'dart:math' as math;

import '../util/bounding_box.dart';

/// Lightweight representation of the drawing operations emitted by Type 1/Type 2 charstrings.
class CharStringPath {
  CharStringPath();

  final List<CharStringPathCommand> _commands = <CharStringPathCommand>[];
  _Point? _currentPoint;
  _Point? _subpathStart;
  double? _minX;
  double? _minY;
  double? _maxX;
  double? _maxY;

  /// Immutable view of the recorded commands.
  List<CharStringPathCommand> get commands => List<CharStringPathCommand>.unmodifiable(_commands);

  /// Returns `true` when a drawing cursor is active.
  bool get hasCurrentPoint => _currentPoint != null;

  /// Returns the current cursor location or `null` when the path is empty.
  _Point? get currentPoint => _currentPoint;

  /// Begins a new contour at ([x], [y]).
  void moveTo(double x, double y) {
    final point = _Point(x, y);
    _commands.add(MoveToCommand(x, y));
    _currentPoint = point;
    _subpathStart = point;
    _updateBounds(x, y);
  }

  /// Draws a straight segment to ([x], [y]).
  void lineTo(double x, double y) {
    final start = _currentPoint;
    if (start == null) {
      moveTo(x, y);
      return;
    }
    _commands.add(LineToCommand(x, y));
    _updateBounds(start.x, start.y);
    _updateBounds(x, y);
    _currentPoint = _Point(x, y);
  }

  /// Draws a cubic Bézier curve using the supplied control and end points.
  void curveTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    final start = _currentPoint;
    if (start == null) {
      moveTo(x3, y3);
      return;
    }
    final ctrl1 = _Point(x1, y1);
    final ctrl2 = _Point(x2, y2);
    final end = _Point(x3, y3);
    _commands.add(CurveToCommand(x1, y1, x2, y2, x3, y3));
    _updateCubicBounds(start, ctrl1, ctrl2, end);
    _currentPoint = end;
  }

  /// Closes the current contour.
  void closePath() {
    _commands.add(const ClosePathCommand());
    final start = _subpathStart;
    _currentPoint = start;
  }

  /// Appends [other] to this path, optionally translating it by ([dx], [dy]).
  void append(CharStringPath other, {double dx = 0, double dy = 0}) {
    for (final command in other._commands) {
      if (command is MoveToCommand) {
        moveTo(command.x + dx, command.y + dy);
      } else if (command is LineToCommand) {
        lineTo(command.x + dx, command.y + dy);
      } else if (command is CurveToCommand) {
        curveTo(
          command.x1 + dx,
          command.y1 + dy,
          command.x2 + dx,
          command.y2 + dy,
          command.x3 + dx,
          command.y3 + dy,
        );
      } else if (command is ClosePathCommand) {
        closePath();
      }
    }
  }

  /// Returns a translated copy of this path.
  CharStringPath transformedCopy({double dx = 0, double dy = 0}) {
    final copy = CharStringPath();
    copy.append(this, dx: dx, dy: dy);
    return copy;
  }

  /// Returns a deep copy of this path.
  CharStringPath clone() => transformedCopy();

  /// Returns the accumulated bounds of the recorded commands.
  BoundingBox getBounds() {
    final minX = _minX ?? 0;
    final minY = _minY ?? 0;
    final maxX = _maxX ?? minX;
    final maxY = _maxY ?? minY;
    return BoundingBox.fromValues(minX, minY, maxX, maxY);
  }

  void _updateCubicBounds(_Point start, _Point ctrl1, _Point ctrl2, _Point end) {
    _updateBounds(start.x, start.y);
    _updateBounds(end.x, end.y);
    _updateBounds(ctrl1.x, ctrl1.y);
    _updateBounds(ctrl2.x, ctrl2.y);

    final tsX = _cubicExtrema(start.x, ctrl1.x, ctrl2.x, end.x);
    for (final t in tsX) {
      if (t <= 0 || t >= 1) {
        continue;
      }
      final x = _evaluateCubic(start.x, ctrl1.x, ctrl2.x, end.x, t);
      final y = _evaluateCubic(start.y, ctrl1.y, ctrl2.y, end.y, t);
      _updateBounds(x, y);
    }

    final tsY = _cubicExtrema(start.y, ctrl1.y, ctrl2.y, end.y);
    for (final t in tsY) {
      if (t <= 0 || t >= 1) {
        continue;
      }
      final x = _evaluateCubic(start.x, ctrl1.x, ctrl2.x, end.x, t);
      final y = _evaluateCubic(start.y, ctrl1.y, ctrl2.y, end.y, t);
      _updateBounds(x, y);
    }
  }

  Iterable<double> _cubicExtrema(double p0, double p1, double p2, double p3) {
    final a = -p0 + 3 * p1 - 3 * p2 + p3;
    final b = 2 * (p0 - 2 * p1 + p2);
    final c = p1 - p0;

    final roots = <double>[];
    if (a.abs() < 1e-12) {
      if (b.abs() < 1e-12) {
        return roots;
      }
      roots.add(-c / b);
      return roots;
    }

    final discriminant = b * b - 4 * a * c;
    if (discriminant < 0) {
      return roots;
    }
    final sqrtDisc = math.sqrt(discriminant);
    final inv2a = 0.5 / a;
    roots.add((-b + sqrtDisc) * inv2a);
    roots.add((-b - sqrtDisc) * inv2a);
    return roots;
  }

  double _evaluateCubic(double p0, double p1, double p2, double p3, double t) {
    final mt = 1 - t;
    return mt * mt * mt * p0 + 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t * p3;
  }

  void _updateBounds(double x, double y) {
    _minX = _minX == null ? x : math.min(_minX!, x);
    _minY = _minY == null ? y : math.min(_minY!, y);
    _maxX = _maxX == null ? x : math.max(_maxX!, x);
    _maxY = _maxY == null ? y : math.max(_maxY!, y);
  }
}

/// Base type for commands recorded inside a [CharStringPath].
abstract class CharStringPathCommand {
  const CharStringPathCommand();
}

class MoveToCommand extends CharStringPathCommand {
  const MoveToCommand(this.x, this.y);
  final double x;
  final double y;
}

class LineToCommand extends CharStringPathCommand {
  const LineToCommand(this.x, this.y);
  final double x;
  final double y;
}

class CurveToCommand extends CharStringPathCommand {
  const CurveToCommand(this.x1, this.y1, this.x2, this.y2, this.x3, this.y3);
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;
}

class ClosePathCommand extends CharStringPathCommand {
  const ClosePathCommand();
}

class _Point {
  _Point(this.x, this.y);
  final double x;
  final double y;
}
