import 'dart:math' as math;

import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_number.dart';
import 'vector.dart';

/// 3x3 matrix implementation matching PDFBox semantics.
class Matrix {
  /// Creates an identity matrix.
  Matrix()
      : _values = <double>[1, 0, 0, 0, 1, 0, 0, 0, 1];

  Matrix._fromValues(List<double> values)
      : _values = List<double>.from(values, growable: false) {
    _checkFinite();
  }

  /// Creates a transformation matrix populated with the supplied entries.
  factory Matrix.fromComponents(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
  ) {
  return Matrix._fromValues(<double>[a, b, 0, c, d, 0, e, f, 1]);
  }

  /// Parses a matrix from a COS array when valid, otherwise returns identity.
  factory Matrix.fromCos(COSArray array) {
    if (array.length < 6) {
      return Matrix();
    }
    final values = <double>[0, 0, 0, 0, 0, 0, 0, 0, 1];
    for (var index = 0; index < 6; index++) {
      final element = array.getObject(index);
      if (element is COSNumber) {
        switch (index) {
          case 0:
            values[0] = element.doubleValue;
            break;
          case 1:
            values[1] = element.doubleValue;
            break;
          case 2:
            values[3] = element.doubleValue;
            break;
          case 3:
            values[4] = element.doubleValue;
            break;
          case 4:
            values[6] = element.doubleValue;
            break;
          case 5:
            values[7] = element.doubleValue;
            break;
        }
      }
    }
    return Matrix._fromValues(values);
  }

  /// Creates a matrix from arbitrary COS content, defaulting to identity.
  factory Matrix.create(COSBase? base) {
    if (base is COSArray) {
      return Matrix.fromCos(base);
    }
    return Matrix();
  }

  final List<double> _values;

  /// Creates a deep copy of this matrix.
  Matrix clone() => Matrix._fromValues(_values);

  /// Returns the component at [row], [column].
  double getValue(int row, int column) => _values[row * 3 + column];

  /// Updates the component at [row], [column].
  void setValue(int row, int column, double value) {
    _values[row * 3 + column] = value;
    _checkFinite();
  }

  /// Concatenates (premultiplies) this matrix with [other].
  void concatenate(Matrix other) {
    final product = _multiply(other._values, _values);
    for (var index = 0; index < 9; index++) {
      _values[index] = product[index];
    }
    _checkFinite();
  }

  /// Multiplies this matrix by [other] returning a new instance.
  Matrix multiply(Matrix other) => Matrix._fromValues(_multiply(_values, other._values));

  /// Applies a translation.
  void translate(double tx, double ty) {
    _values[6] += tx * _values[0] + ty * _values[3];
    _values[7] += tx * _values[1] + ty * _values[4];
    _values[8] += tx * _values[2] + ty * _values[5];
    _checkFinite();
  }

  /// Applies a scale transformation.
  void scale(double sx, double sy) {
    _values[0] *= sx;
    _values[1] *= sx;
    _values[2] *= sx;
    _values[3] *= sy;
    _values[4] *= sy;
    _values[5] *= sy;
    _checkFinite();
  }

  /// Applies a rotation around the origin.
  void rotate(double radians) {
    concatenate(getRotateInstance(radians, 0, 0));
  }

  /// Transforms [vector] and returns the result.
  Vector transform(Vector vector) {
    final x = vector.x;
    final y = vector.y;
    return Vector(
      x * _values[0] + y * _values[3] + _values[6],
      x * _values[1] + y * _values[4] + _values[7],
    );
  }

  /// Transforms the scalar components ([x], [y]).
  Vector transformPoint(double x, double y) {
    return Vector(
      x * _values[0] + y * _values[3] + _values[6],
      x * _values[1] + y * _values[4] + _values[7],
    );
  }

  /// Copies this matrix to a new list of doubles.
  List<double> toList() => List<double>.from(_values, growable: false);

  /// Creates a scale matrix instance.
  static Matrix getScaleInstance(double sx, double sy) =>
      Matrix.fromComponents(sx, 0, 0, sy, 0, 0);

  /// Creates a translation matrix instance.
  static Matrix getTranslateInstance(double tx, double ty) =>
      Matrix.fromComponents(1, 0, 0, 1, tx, ty);

  /// Creates a rotation matrix instance around a reference point.
  static Matrix getRotateInstance(double radians, double x, double y) {
    final cosTheta = math.cos(radians);
    final sinTheta = math.sin(radians);
    final rotation = Matrix._fromValues(<double>[
      cosTheta,
      sinTheta,
      0,
      -sinTheta,
      cosTheta,
      0,
      0,
      0,
      1,
    ]);
    if (x == 0 && y == 0) {
      return rotation;
    }
    final translateToOrigin = Matrix.getTranslateInstance(-x, -y);
    final translateBack = Matrix.getTranslateInstance(x, y);
    return translateBack.multiply(rotation).multiply(translateToOrigin);
  }

  List<double> _multiply(List<double> a, List<double> b) {
    return <double>[
      a[0] * b[0] + a[1] * b[3] + a[2] * b[6],
      a[0] * b[1] + a[1] * b[4] + a[2] * b[7],
      a[0] * b[2] + a[1] * b[5] + a[2] * b[8],
      a[3] * b[0] + a[4] * b[3] + a[5] * b[6],
      a[3] * b[1] + a[4] * b[4] + a[5] * b[7],
      a[3] * b[2] + a[4] * b[5] + a[5] * b[8],
      a[6] * b[0] + a[7] * b[3] + a[8] * b[6],
      a[6] * b[1] + a[7] * b[4] + a[8] * b[7],
      a[6] * b[2] + a[7] * b[5] + a[8] * b[8],
    ];
  }

  void _checkFinite() {
    for (final value in _values) {
      if (!value.isFinite) {
        throw ArgumentError('Matrix contains non-finite value: $value');
      }
    }
  }
}
