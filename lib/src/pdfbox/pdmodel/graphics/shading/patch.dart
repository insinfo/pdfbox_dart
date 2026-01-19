part of 'pd_shading.dart';

/// Helper class to store a point's coordinate and its corresponding color.
/// Port of PDFBox CoordinateColorPair.java
class CoordinateColorPair {
  final Point coordinate;
  final List<double> color;

  CoordinateColorPair(this.coordinate, List<double> c) : color = List<double>.from(c);
}

/// Class to describe a cubic Bezier curve edge.
/// Port of PDFBox CubicBezierCurve.java
class CubicBezierCurve {
  final List<Point> _controlPoints;
  final int _level;
  late final List<Point> _curve;

  /// Constructor of CubicBezierCurve
  /// [ctrlPnts] 4 control points [p0, p1, p2, p3]
  /// [level] dividing level, if l = 0, one cubic Bezier curve is divided
  /// into 2^0 = 1 segments, if l = n, one cubic Bezier curve is divided into
  /// 2^n segments
  CubicBezierCurve(List<Point> ctrlPnts, int level)
      : _controlPoints = List<Point>.from(ctrlPnts),
        _level = level {
    _curve = _getPoints(_level);
  }

  int get level => _level;

  List<Point> _getPoints(int l) {
    if (l < 0) {
      l = 0;
    }
    final sz = (1 << l) + 1;
    final res = <Point>[];
    final step = 1.0 / (sz - 1);
    var t = -step;

    for (var i = 0; i < sz; i++) {
      t += step;
      final t2 = t * t;
      final t3 = t2 * t;
      final mt = 1 - t;
      final mt2 = mt * mt;
      final mt3 = mt2 * mt;

      final tmpX = mt3 * _controlPoints[0].x +
          3 * t * mt2 * _controlPoints[1].x +
          3 * t2 * mt * _controlPoints[2].x +
          t3 * _controlPoints[3].x;
      final tmpY = mt3 * _controlPoints[0].y +
          3 * t * mt2 * _controlPoints[1].y +
          3 * t2 * mt * _controlPoints[2].y +
          t3 * _controlPoints[3].y;
      res.add(Point(tmpX, tmpY));
    }
    return res;
  }

  List<Point> getCubicBezierCurve() => _curve;

  @override
  String toString() {
    return 'CubicBezierCurve{control points: $_controlPoints}';
  }
}

/// Abstract base class for patches (CoonsPatch and TensorPatch).
/// Port of PDFBox Patch.java
abstract class Patch {
  List<List<Point>>? controlPoints;
  final List<List<double>> cornerColor;
  List<int>? level;
  List<ShadedTriangle> listOfTriangles = <ShadedTriangle>[];

  Patch(List<List<double>> color)
      : cornerColor = color.map((e) => List<double>.from(e)).toList();

  /// Get the implicit edge for flag = 1.
  List<Point> getFlag1Edge();

  /// Get the implicit edge for flag = 2.
  List<Point> getFlag2Edge();

  /// Get the implicit edge for flag = 3.
  List<Point> getFlag3Edge();

  /// Get the implicit color for flag = 1.
  List<List<double>> getFlag1Color() {
    final numberOfColorComponents = cornerColor[0].length;
    final implicitCornerColor = List<List<double>>.generate(
        2, (_) => List<double>.filled(numberOfColorComponents, 0));
    for (var i = 0; i < numberOfColorComponents; i++) {
      implicitCornerColor[0][i] = cornerColor[1][i];
      implicitCornerColor[1][i] = cornerColor[2][i];
    }
    return implicitCornerColor;
  }

  /// Get implicit color for flag = 2.
  List<List<double>> getFlag2Color() {
    final numberOfColorComponents = cornerColor[0].length;
    final implicitCornerColor = List<List<double>>.generate(
        2, (_) => List<double>.filled(numberOfColorComponents, 0));
    for (var i = 0; i < numberOfColorComponents; i++) {
      implicitCornerColor[0][i] = cornerColor[2][i];
      implicitCornerColor[1][i] = cornerColor[3][i];
    }
    return implicitCornerColor;
  }

  /// Get implicit color for flag = 3.
  List<List<double>> getFlag3Color() {
    final numberOfColorComponents = cornerColor[0].length;
    final implicitCornerColor = List<List<double>>.generate(
        2, (_) => List<double>.filled(numberOfColorComponents, 0));
    for (var i = 0; i < numberOfColorComponents; i++) {
      implicitCornerColor[0][i] = cornerColor[3][i];
      implicitCornerColor[1][i] = cornerColor[0][i];
    }
    return implicitCornerColor;
  }

  /// Calculate the distance from point ps to point pe.
  double getLen(Point ps, Point pe) {
    final x = pe.x - ps.x;
    final y = pe.y - ps.y;
    return math.sqrt(x * x + y * y);
  }

  /// Whether the four control points are on a line.
  bool isEdgeALine(List<Point> ctl) {
    final ctl1 = _edgeEquationValue(ctl[1], ctl[0], ctl[3]).abs();
    final ctl2 = _edgeEquationValue(ctl[2], ctl[0], ctl[3]).abs();
    final x = (ctl[0].x - ctl[3].x).abs();
    final y = (ctl[0].y - ctl[3].y).abs();
    return (ctl1 <= x && ctl2 <= x) || (ctl1 <= y && ctl2 <= y);
  }

  /// Edge equation value calculation.
  double _edgeEquationValue(Point p, Point p1, Point p2) {
    return (p2.y - p1.y) * (p.x - p1.x) - (p2.x - p1.x) * (p.y - p1.y);
  }

  /// Whether two points overlap.
  bool _overlaps(Point p0, Point p1) {
    return (p0.x - p1.x).abs() < 0.001 && (p0.y - p1.y).abs() < 0.001;
  }

  /// Convert patch coordinates and colors into shaded triangles.
  List<ShadedTriangle> getShadedTriangles(List<List<CoordinateColorPair>> patchCC) {
    final list = <ShadedTriangle>[];
    final szV = patchCC.length;
    final szU = patchCC[0].length;

    for (var i = 1; i < szV; i++) {
      for (var j = 1; j < szU; j++) {
        final p0 = patchCC[i - 1][j - 1].coordinate;
        final p1 = patchCC[i - 1][j].coordinate;
        final p2 = patchCC[i][j].coordinate;
        final p3 = patchCC[i][j - 1].coordinate;

        var ll = true;
        if (_overlaps(p0, p1) || _overlaps(p0, p3)) {
          ll = false;
        } else {
          // Lower left triangle
          final llCorner = [p0, p1, p3];
          final llColor = [
            patchCC[i - 1][j - 1].color,
            patchCC[i - 1][j].color,
            patchCC[i][j - 1].color
          ];
          list.add(ShadedTriangle(llCorner, llColor));
        }

        if (!(ll && (_overlaps(p2, p1) || _overlaps(p2, p3)))) {
          // Upper right triangle
          final urCorner = [p3, p1, p2];
          final urColor = [
            patchCC[i][j - 1].color,
            patchCC[i - 1][j].color,
            patchCC[i][j].color
          ];
          list.add(ShadedTriangle(urCorner, urColor));
        }
      }
    }
    return list;
  }
}

/// CoonsPatch for Type 6 shading.
/// Port of PDFBox CoonsPatch.java
class CoonsPatch extends Patch {
  CoonsPatch(List<Point> points, List<List<double>> color) : super(color) {
    controlPoints = _reshapeControlPoints(points);
    level = _calcLevel();
    listOfTriangles = _getTriangles();
  }

  List<List<Point>> _reshapeControlPoints(List<Point> points) {
    // Adjust the 12 control points to 4 groups (edges)
    return [
      [points[0], points[11], points[10], points[9]], // c1
      [points[3], points[4], points[5], points[6]], // c2
      [points[0], points[1], points[2], points[3]], // d1
      [points[9], points[8], points[7], points[6]], // d2
    ];
  }

  List<int> _calcLevel() {
    final l = [4, 4];

    // If two opposite edges are both lines, reduce dividing level
    if (isEdgeALine(controlPoints![0]) && isEdgeALine(controlPoints![1])) {
      final lc1 = getLen(controlPoints![0][0], controlPoints![0][3]);
      final lc2 = getLen(controlPoints![1][0], controlPoints![1][3]);
      if (lc1 > 800 || lc2 > 800) {
        // keep 4
      } else if (lc1 > 400 || lc2 > 400) {
        l[0] = 3;
      } else if (lc1 > 200 || lc2 > 200) {
        l[0] = 2;
      } else {
        l[0] = 1;
      }
    }

    if (isEdgeALine(controlPoints![2]) && isEdgeALine(controlPoints![3])) {
      final ld1 = getLen(controlPoints![2][0], controlPoints![2][3]);
      final ld2 = getLen(controlPoints![3][0], controlPoints![3][3]);
      if (ld1 > 800 || ld2 > 800) {
        // keep 4
      } else if (ld1 > 400 || ld2 > 400) {
        l[1] = 3;
      } else if (ld1 > 200 || ld2 > 200) {
        l[1] = 2;
      } else {
        l[1] = 1;
      }
    }
    return l;
  }

  List<ShadedTriangle> _getTriangles() {
    final eC1 = CubicBezierCurve(controlPoints![0], level![0]);
    final eC2 = CubicBezierCurve(controlPoints![1], level![0]);
    final eD1 = CubicBezierCurve(controlPoints![2], level![1]);
    final eD2 = CubicBezierCurve(controlPoints![3], level![1]);
    final patchCC = _getPatchCoordinatesColor(eC1, eC2, eD1, eD2);
    return getShadedTriangles(patchCC);
  }

  @override
  List<Point> getFlag1Edge() => List<Point>.from(controlPoints![1]);

  @override
  List<Point> getFlag2Edge() {
    return [
      controlPoints![3][3],
      controlPoints![3][2],
      controlPoints![3][1],
      controlPoints![3][0],
    ];
  }

  @override
  List<Point> getFlag3Edge() {
    return [
      controlPoints![0][3],
      controlPoints![0][2],
      controlPoints![0][1],
      controlPoints![0][0],
    ];
  }

  List<List<CoordinateColorPair>> _getPatchCoordinatesColor(
    CubicBezierCurve c1,
    CubicBezierCurve c2,
    CubicBezierCurve d1,
    CubicBezierCurve d2,
  ) {
    final curveC1 = c1.getCubicBezierCurve();
    final curveC2 = c2.getCubicBezierCurve();
    final curveD1 = d1.getCubicBezierCurve();
    final curveD2 = d2.getCubicBezierCurve();

    final numberOfColorComponents = cornerColor[0].length;
    final szV = curveD1.length;
    final szU = curveC1.length;

    final patchCC = List<List<CoordinateColorPair>>.generate(
      szV,
      (_) => List<CoordinateColorPair>.filled(
          szU, CoordinateColorPair(const Point(0, 0), <double>[])),
    );

    final stepV = 1.0 / (szV - 1);
    final stepU = 1.0 / (szU - 1);
    var v = -stepV;

    for (var i = 0; i < szV; i++) {
      v += stepV;
      var u = -stepU;
      for (var j = 0; j < szU; j++) {
        u += stepU;

        final scx = (1 - v) * curveC1[j].x + v * curveC2[j].x;
        final scy = (1 - v) * curveC1[j].y + v * curveC2[j].y;
        final sdx = (1 - u) * curveD1[i].x + u * curveD2[i].x;
        final sdy = (1 - u) * curveD1[i].y + u * curveD2[i].y;
        final sbx = (1 - v) *
                ((1 - u) * controlPoints![0][0].x +
                    u * controlPoints![0][3].x) +
            v *
                ((1 - u) * controlPoints![1][0].x +
                    u * controlPoints![1][3].x);
        final sby = (1 - v) *
                ((1 - u) * controlPoints![0][0].y +
                    u * controlPoints![0][3].y) +
            v *
                ((1 - u) * controlPoints![1][0].y +
                    u * controlPoints![1][3].y);

        final sx = scx + sdx - sbx;
        final sy = scy + sdy - sby;

        final paramSC = List<double>.filled(numberOfColorComponents, 0);
        for (var ci = 0; ci < numberOfColorComponents; ci++) {
          paramSC[ci] = ((1 - v) *
                      ((1 - u) * cornerColor[0][ci] + u * cornerColor[3][ci]) +
                  v * ((1 - u) * cornerColor[1][ci] + u * cornerColor[2][ci]))
              .toDouble();
        }
        patchCC[i][j] = CoordinateColorPair(Point(sx, sy), paramSC);
      }
    }
    return patchCC;
  }
}

/// TensorPatch for Type 7 shading.
/// Port of PDFBox TensorPatch.java
class TensorPatch extends Patch {
  TensorPatch(List<Point> tcp, List<List<double>> color) : super(color) {
    controlPoints = _reshapeControlPoints(tcp);
    level = _calcLevel();
    listOfTriangles = _getTriangles();
  }

  List<List<Point>> _reshapeControlPoints(List<Point> tcp) {
    // Order the 16 1D points to a 4x4 matrix
    final square = List<List<Point>>.generate(
        4, (_) => List<Point>.filled(4, const Point(0, 0)));

    for (var i = 0; i <= 3; i++) {
      square[0][i] = tcp[i];
      square[3][i] = tcp[9 - i];
    }
    for (var i = 1; i <= 2; i++) {
      square[i][0] = tcp[12 - i];
      square[i][2] = tcp[12 + i];
      square[i][3] = tcp[3 + i];
    }
    square[1][1] = tcp[12];
    square[2][1] = tcp[15];
    return square;
  }

  List<int> _calcLevel() {
    final l = [4, 4];

    final ctlC1 = <Point>[];
    final ctlC2 = <Point>[];
    for (var j = 0; j < 4; j++) {
      ctlC1.add(controlPoints![j][0]);
      ctlC2.add(controlPoints![j][3]);
    }

    if (isEdgeALine(ctlC1) && isEdgeALine(ctlC2)) {
      if (!_isOnSameSideCC(controlPoints![1][1]) &&
          !_isOnSameSideCC(controlPoints![1][2]) &&
          !_isOnSameSideCC(controlPoints![2][1]) &&
          !_isOnSameSideCC(controlPoints![2][2])) {
        final lc1 = getLen(ctlC1[0], ctlC1[3]);
        final lc2 = getLen(ctlC2[0], ctlC2[3]);
        if (lc1 > 800 || lc2 > 800) {
          // keep 4
        } else if (lc1 > 400 || lc2 > 400) {
          l[0] = 3;
        } else if (lc1 > 200 || lc2 > 200) {
          l[0] = 2;
        } else {
          l[0] = 1;
        }
      }
    }

    if (isEdgeALine(controlPoints![0]) && isEdgeALine(controlPoints![3])) {
      if (!_isOnSameSideDD(controlPoints![1][1]) &&
          !_isOnSameSideDD(controlPoints![1][2]) &&
          !_isOnSameSideDD(controlPoints![2][1]) &&
          !_isOnSameSideDD(controlPoints![2][2])) {
        final ld1 = getLen(controlPoints![0][0], controlPoints![0][3]);
        final ld2 = getLen(controlPoints![3][0], controlPoints![3][3]);
        if (ld1 > 800 || ld2 > 800) {
          // keep 4
        } else if (ld1 > 400 || ld2 > 400) {
          l[1] = 3;
        } else if (ld1 > 200 || ld2 > 200) {
          l[1] = 2;
        } else {
          l[1] = 1;
        }
      }
    }
    return l;
  }

  bool _isOnSameSideCC(Point p) {
    final cc = _edgeEquationValue(
            p, controlPoints![0][0], controlPoints![3][0]) *
        _edgeEquationValue(p, controlPoints![0][3], controlPoints![3][3]);
    return cc > 0;
  }

  bool _isOnSameSideDD(Point p) {
    final dd = _edgeEquationValue(
            p, controlPoints![0][0], controlPoints![0][3]) *
        _edgeEquationValue(p, controlPoints![3][0], controlPoints![3][3]);
    return dd > 0;
  }

  List<ShadedTriangle> _getTriangles() {
    final patchCC = _getPatchCoordinatesColor();
    return getShadedTriangles(patchCC);
  }

  @override
  List<Point> getFlag1Edge() {
    return [
      controlPoints![0][3],
      controlPoints![1][3],
      controlPoints![2][3],
      controlPoints![3][3],
    ];
  }

  @override
  List<Point> getFlag2Edge() {
    return [
      controlPoints![3][3],
      controlPoints![3][2],
      controlPoints![3][1],
      controlPoints![3][0],
    ];
  }

  @override
  List<Point> getFlag3Edge() {
    return [
      controlPoints![3][0],
      controlPoints![2][0],
      controlPoints![1][0],
      controlPoints![0][0],
    ];
  }

  List<List<CoordinateColorPair>> _getPatchCoordinatesColor() {
    final numberOfColorComponents = cornerColor[0].length;
    final bernsteinPolyU = _getBernsteinPolynomials(level![0]);
    final szU = bernsteinPolyU[0].length;
    final bernsteinPolyV = _getBernsteinPolynomials(level![1]);
    final szV = bernsteinPolyV[0].length;

    final patchCC = List<List<CoordinateColorPair>>.generate(
      szV,
      (_) => List<CoordinateColorPair>.filled(
          szU, CoordinateColorPair(const Point(0, 0), <double>[])),
    );

    final stepU = 1.0 / (szU - 1);
    final stepV = 1.0 / (szV - 1);
    var v = -stepV;

    for (var k = 0; k < szV; k++) {
      v += stepV;
      var u = -stepU;
      for (var l = 0; l < szU; l++) {
        var tmpx = 0.0;
        var tmpy = 0.0;

        for (var i = 0; i < 4; i++) {
          for (var j = 0; j < 4; j++) {
            tmpx += controlPoints![i][j].x *
                bernsteinPolyU[i][l] *
                bernsteinPolyV[j][k];
            tmpy += controlPoints![i][j].y *
                bernsteinPolyU[i][l] *
                bernsteinPolyV[j][k];
          }
        }

        u += stepU;
        final paramSC = List<double>.filled(numberOfColorComponents, 0);
        for (var ci = 0; ci < numberOfColorComponents; ci++) {
          paramSC[ci] = ((1 - v) *
                      ((1 - u) * cornerColor[0][ci] + u * cornerColor[3][ci]) +
                  v * ((1 - u) * cornerColor[1][ci] + u * cornerColor[2][ci]))
              .toDouble();
        }
        patchCC[k][l] = CoordinateColorPair(Point(tmpx, tmpy), paramSC);
      }
    }
    return patchCC;
  }

  List<List<double>> _getBernsteinPolynomials(int lvl) {
    final sz = (1 << lvl) + 1;
    final poly = List<List<double>>.generate(
        4, (_) => List<double>.filled(sz, 0));
    final step = 1.0 / (sz - 1);
    var t = -step;

    for (var i = 0; i < sz; i++) {
      t += step;
      final mt = 1 - t;
      poly[0][i] = mt * mt * mt;
      poly[1][i] = 3 * t * mt * mt;
      poly[2][i] = 3 * t * t * mt;
      poly[3][i] = t * t * t;
    }
    return poly;
  }
}
