part of 'pd_shading.dart';

/// Vertex for Type 4 and Type 5 shadings.
/// Port of PDFBox Vertex.java
class ShadingVertex {
  final Point point;
  final List<double> color;

  ShadingVertex(this.point, List<double> c) : color = List<double>.from(c);

  @override
  String toString() {
    final sb = StringBuffer();
    for (var i = 0; i < color.length; i++) {
      if (i > 0) {
        sb.write(' ');
      }
      sb.write(color[i].toStringAsFixed(2));
    }
    return 'ShadingVertex{ $point, colors=[$sb] }';
  }
}

/// A point in 2D space with integer coordinates.
class IntPoint {
  final int x;
  final int y;

  const IntPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntPoint && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => 'IntPoint($x, $y)';
}

/// A point in 2D space with double coordinates.
class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);

  @override
  String toString() => 'Point($x, $y)';
}

/// This class describes a rasterized line.
/// Port of PDFBox Line.java
class ShadingLine {
  final IntPoint point0;
  final IntPoint point1;
  final List<double> color0;
  final List<double> color1;
  final Set<IntPoint> linePoints;

  ShadingLine(IntPoint p0, IntPoint p1, List<double> c0, List<double> c1)
      : point0 = p0,
        point1 = p1,
        color0 = List<double>.from(c0),
        color1 = List<double>.from(c1),
        linePoints = _calcLine(p0.x, p0.y, p1.x, p1.y);

  /// Calculate the points of a line with Bresenham's line algorithm.
  static Set<IntPoint> _calcLine(int x0, int y0, int x1, int y1) {
    final points = <IntPoint>{};
    final dx = (x1 - x0).abs();
    final dy = (y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx - dy;
    var cx = x0;
    var cy = y0;
    
    while (true) {
      points.add(IntPoint(cx, cy));
      if (cx == x1 && cy == y1) {
        break;
      }
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        cx += sx;
      }
      if (e2 < dx) {
        err += dx;
        cy += sy;
      }
    }
    return points;
  }

  /// Calculate the color of a point on a rasterized line by linear interpolation.
  List<double> calcColor(IntPoint p) {
    if (point0.x == point1.x && point0.y == point1.y) {
      return color0;
    }
    final numberOfColorComponents = color0.length;
    final pc = List<double>.filled(numberOfColorComponents, 0);
    
    if (point0.x == point1.x) {
      final l = (point1.y - point0.y).toDouble();
      for (var i = 0; i < numberOfColorComponents; i++) {
        pc[i] = (color0[i] * (point1.y - p.y) / l +
            color1[i] * (p.y - point0.y) / l);
      }
    } else {
      final l = (point1.x - point0.x).toDouble();
      for (var i = 0; i < numberOfColorComponents; i++) {
        pc[i] = (color0[i] * (point1.x - p.x) / l +
            color1[i] * (p.x - point0.x) / l);
      }
    }
    return pc;
  }
}

/// This is an assistant class for accomplishing type 4, 5, 6 and 7 shading.
/// It describes a triangle which is used to compose a patch.
/// Port of PDFBox ShadedTriangle.java
class ShadedTriangle {
  final List<Point> corner; // vertices coordinates of a triangle
  final List<List<double>> color;
  final double _area; // area of the triangle

  /// degree = 3 describes a normal triangle,
  /// degree = 2 when a triangle degenerates to a line,
  /// degree = 1 when a triangle degenerates to a point
  final int _degree;

  /// describes a rasterized line when a triangle degenerates to a line
  final ShadingLine? _line;

  // corner's edge (the opposite edge of a corner) equation value
  final double _v0;
  final double _v1;
  final double _v2;

  ShadedTriangle._(
    this.corner,
    this.color,
    this._area,
    this._degree,
    this._line,
    this._v0,
    this._v1,
    this._v2,
  );

  factory ShadedTriangle(List<Point> p, List<List<double>> c) {
    final corner = List<Point>.from(p);
    final color = c.map((e) => List<double>.from(e)).toList();
    final area = _getArea(p[0], p[1], p[2]);
    final degree = _calcDeg(p);

    ShadingLine? line;
    if (degree == 2) {
      if (_overlaps(corner[1], corner[2]) && !_overlaps(corner[0], corner[2])) {
        final p0 = IntPoint(corner[0].x.round(), corner[0].y.round());
        final p1 = IntPoint(corner[2].x.round(), corner[2].y.round());
        line = ShadingLine(p0, p1, color[0], color[2]);
      } else {
        final p0 = IntPoint(corner[1].x.round(), corner[1].y.round());
        final p1 = IntPoint(corner[2].x.round(), corner[2].y.round());
        line = ShadingLine(p0, p1, color[1], color[2]);
      }
    }

    final v0 = _edgeEquationValue(p[0], p[1], p[2]);
    final v1 = _edgeEquationValue(p[1], p[2], p[0]);
    final v2 = _edgeEquationValue(p[2], p[0], p[1]);

    return ShadedTriangle._(corner, color, area, degree, line, v0, v1, v2);
  }

  /// Calculate the degree value of a triangle.
  static int _calcDeg(List<Point> p) {
    final set = <IntPoint>{};
    for (final pt in p) {
      set.add(IntPoint((pt.x * 1000).round(), (pt.y * 1000).round()));
    }
    return set.length;
  }

  int get deg => _degree;

  /// Get the boundary of a triangle.
  /// Returns [xmin, xmax, ymin, ymax]
  List<int> getBoundary() {
    final x0 = corner[0].x.round();
    final x1 = corner[1].x.round();
    final x2 = corner[2].x.round();
    final y0 = corner[0].y.round();
    final y1 = corner[1].y.round();
    final y2 = corner[2].y.round();

    return [
      [x0, x1, x2].reduce((a, b) => a < b ? a : b),
      [x0, x1, x2].reduce((a, b) => a > b ? a : b),
      [y0, y1, y2].reduce((a, b) => a < b ? a : b),
      [y0, y1, y2].reduce((a, b) => a > b ? a : b),
    ];
  }

  /// Get the line of a triangle.
  ShadingLine? get line => _line;

  /// Whether a point is contained in this ShadedTriangle.
  bool contains(Point p) {
    if (_degree == 1) {
      return _overlaps(corner[0], p) ||
          _overlaps(corner[1], p) ||
          _overlaps(corner[2], p);
    } else if (_degree == 2) {
      final tp = IntPoint(p.x.round(), p.y.round());
      return _line!.linePoints.contains(tp);
    }

    // Normal triangle case
    final pv0 = _edgeEquationValue(p, corner[1], corner[2]);
    if (pv0 * _v0 < 0) {
      return false;
    }
    final pv1 = _edgeEquationValue(p, corner[2], corner[0]);
    if (pv1 * _v1 < 0) {
      return false;
    }
    final pv2 = _edgeEquationValue(p, corner[0], corner[1]);
    return pv2 * _v2 >= 0;
  }

  /// Check whether two points overlap each other.
  static bool _overlaps(Point p0, Point p1) {
    return (p0.x - p1.x).abs() < 0.001 && (p0.y - p1.y).abs() < 0.001;
  }

  /// Edge equation value calculation.
  static double _edgeEquationValue(Point p, Point p1, Point p2) {
    return (p2.y - p1.y) * (p.x - p1.x) - (p2.x - p1.x) * (p.y - p1.y);
  }

  /// Calculate the area of a triangle.
  static double _getArea(Point a, Point b, Point c) {
    return ((c.x - b.x) * (c.y - a.y) - (c.x - a.x) * (c.y - b.y)).abs() / 2.0;
  }

  /// Calculate the color of a point.
  List<double> calcColor(Point p) {
    final numberOfColorComponents = color[0].length;
    final pCol = List<double>.filled(numberOfColorComponents, 0);

    switch (_degree) {
      case 1:
        // average
        for (var i = 0; i < numberOfColorComponents; i++) {
          pCol[i] = (color[0][i] + color[1][i] + color[2][i]) / 3.0;
        }
        break;
      case 2:
        // linear interpolation
        final tp = IntPoint(p.x.round(), p.y.round());
        final lineColor = _line!.calcColor(tp);
        for (var i = 0; i < numberOfColorComponents; i++) {
          pCol[i] = lineColor[i];
        }
        break;
      default:
        // barycentric interpolation
        final aw = _getArea(p, corner[1], corner[2]) / _area;
        final bw = _getArea(p, corner[2], corner[0]) / _area;
        final cw = _getArea(p, corner[0], corner[1]) / _area;
        for (var i = 0; i < numberOfColorComponents; i++) {
          pCol[i] = color[0][i] * aw + color[1][i] * bw + color[2][i] * cw;
        }
        break;
    }
    return pCol;
  }

  @override
  String toString() => '${corner[0]} ${corner[1]} ${corner[2]}';
}

