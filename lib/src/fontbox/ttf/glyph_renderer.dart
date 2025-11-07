import 'package:logging/logging.dart';

import 'glyf/glyf_descript.dart';
import 'glyf/glyph_description.dart';

/// Produces a vector path for a glyph described by TrueType contour data.
///
/// This is a direct port of Apache PDFBox's glyph renderer logic, adapted to
/// emit a lightweight [GlyphPath] representation instead of `GeneralPath`.
class GlyphRenderer {
  GlyphRenderer(this._glyphDescription);

  static final Logger _log = Logger('fontbox.GlyphRenderer');

  final GlyphDescription _glyphDescription;

  /// Computes the drawable path for [_glyphDescription].
  GlyphPath getPath() {
    final points = _describe(_glyphDescription);
    return _calculatePath(points);
  }

  List<_GlyphPoint> _describe(GlyphDescription description) {
    final pointCount = description.pointCount;
    if (pointCount == 0) {
      return const <_GlyphPoint>[];
    }

    final contourCount = description.contourCount;
    final points = <_GlyphPoint>[];

    var endPointIndex = 0;
    int? endPointOfContourIndex;

    for (var i = 0; i < pointCount; i++) {
      if (endPointOfContourIndex == null && endPointIndex < contourCount) {
        endPointOfContourIndex = description.getEndPtOfContours(endPointIndex);
      }

      final onCurve = (description.getFlags(i) & GlyfDescript.ON_CURVE) != 0;
      final endOfContour =
          endPointOfContourIndex != null && endPointOfContourIndex == i;

      points.add(_GlyphPoint(
        description.getXCoordinate(i),
        description.getYCoordinate(i),
        onCurve,
        endOfContour,
      ));

      if (endOfContour) {
        endPointIndex++;
        endPointOfContourIndex = null;
      }
    }

    return points;
  }

  GlyphPath _calculatePath(List<_GlyphPoint> points) {
    final path = GlyphPath();
    if (points.isEmpty) {
      return path;
    }

    var start = 0;
    for (var p = 0; p < points.length; ++p) {
      if (!points[p].endOfContour) {
        continue;
      }

      final contour = <_GlyphPoint>[];
      for (var q = start; q <= p; ++q) {
        contour.add(points[q]);
      }

      final firstPoint = contour.first;
      final lastPoint = contour.last;

      if (firstPoint.onCurve) {
        contour.add(firstPoint);
      } else if (lastPoint.onCurve) {
        contour.insert(0, lastPoint);
      } else {
        final mid = _midPoint(firstPoint, lastPoint);
        contour.insert(0, mid);
        contour.add(mid);
      }

      _moveTo(path, contour[0]);

      for (var j = 1; j < contour.length; ++j) {
        final point = contour[j];
        if (point.onCurve) {
          _lineTo(path, point);
        } else {
          assert(j + 1 < contour.length,
              'Contour missing trailing point for off-curve segment');
          final next = contour[j + 1];
          if (next.onCurve) {
            _quadTo(path, point, next);
            j++;
          } else {
            _quadTo(path, point, _midPoint(point, next));
          }
        }
      }

      path.closePath();
      start = p + 1;
    }

    return path;
  }

  void _moveTo(GlyphPath path, _GlyphPoint point) {
    path.moveTo(point.x.toDouble(), point.y.toDouble());
    if (_log.isLoggable(Level.FINEST)) {
      _log.finest('moveTo: ${point.x},${point.y}');
    }
  }

  void _lineTo(GlyphPath path, _GlyphPoint point) {
    path.lineTo(point.x.toDouble(), point.y.toDouble());
    if (_log.isLoggable(Level.FINEST)) {
      _log.finest('lineTo: ${point.x},${point.y}');
    }
  }

  void _quadTo(GlyphPath path, _GlyphPoint control, _GlyphPoint point) {
    path.quadTo(control.x.toDouble(), control.y.toDouble(), point.x.toDouble(),
        point.y.toDouble());
    if (_log.isLoggable(Level.FINEST)) {
      _log.finest('quadTo: ${control.x},${control.y} ${point.x},${point.y}');
    }
  }

  int _midValue(int a, int b) => a + ((b - a) ~/ 2);

  _GlyphPoint _midPoint(_GlyphPoint a, _GlyphPoint b) =>
      _GlyphPoint(_midValue(a.x, b.x), _midValue(a.y, b.y), true, false);
}

/// Lightweight vector path comprised of TrueType drawing commands.
class GlyphPath {
  final List<GlyphPathCommand> _commands = <GlyphPathCommand>[];

  bool get isEmpty => _commands.isEmpty;
  List<GlyphPathCommand> get commands =>
      List<GlyphPathCommand>.unmodifiable(_commands);

  void moveTo(double x, double y) => _commands.add(MoveToCommand(x, y));
  void lineTo(double x, double y) => _commands.add(LineToCommand(x, y));
  void quadTo(double cx, double cy, double x, double y) =>
      _commands.add(QuadToCommand(cx, cy, x, y));
  void closePath() => _commands.add(const ClosePathCommand());
}

/// Base type for commands recorded within a [GlyphPath].
abstract class GlyphPathCommand {
  const GlyphPathCommand();
}

/// `moveTo` command establishing the next contour start point.
class MoveToCommand extends GlyphPathCommand {
  const MoveToCommand(this.x, this.y);
  final double x;
  final double y;
}

/// `lineTo` command adding a straight segment.
class LineToCommand extends GlyphPathCommand {
  const LineToCommand(this.x, this.y);
  final double x;
  final double y;
}

/// `quadTo` command adding a quadratic Bézier segment.
class QuadToCommand extends GlyphPathCommand {
  const QuadToCommand(this.cx, this.cy, this.x, this.y);
  final double cx;
  final double cy;
  final double x;
  final double y;
}

/// `closePath` command terminating the current contour.
class ClosePathCommand extends GlyphPathCommand {
  const ClosePathCommand();
}

class _GlyphPoint {
  _GlyphPoint(this.x, this.y, this.onCurve, this.endOfContour);

  final int x;
  final int y;
  final bool onCurve;
  final bool endOfContour;
}
