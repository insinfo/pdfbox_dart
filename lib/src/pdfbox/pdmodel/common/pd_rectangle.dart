import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_number.dart';

/// Represents a rectangle in PDF coordinates.
class PDRectangle {
  PDRectangle(
      this.lowerLeftX, this.lowerLeftY, this.upperRightX, this.upperRightY);

  factory PDRectangle.fromCOSArray(COSArray array) {
    if (array.length < 4) {
      throw ArgumentError(
          'COSArray must have at least four elements to form a rectangle');
    }
    return PDRectangle(
      _toDouble(array[0]),
      _toDouble(array[1]),
      _toDouble(array[2]),
      _toDouble(array[3]),
    );
  }

  /// Attempts to create a [PDRectangle] from a COS-based value.
  factory PDRectangle.fromCOSObject(COSBase base) {
    if (base is COSArray) {
      return PDRectangle.fromCOSArray(base);
    }
    throw ArgumentError('Expected COSArray when constructing PDRectangle');
  }

  double lowerLeftX;
  double lowerLeftY;
  double upperRightX;
  double upperRightY;

  bool contains(double x, double y) {
    double x0 = lowerLeftX;
    double y0 = lowerLeftY;
    double x1 = upperRightX;
    double y1 = upperRightY;
    return x >= x0 && x <= x1 && y >= y0 && y <= y1;
  }

  /// A rectangle the size of U.S. Letter, 8.5" x 11".
  static final PDRectangle letter = PDRectangle(0, 0, 612, 792);

  /// A rectangle the size of U.S. Legal, 8.5" x 14".
  static final PDRectangle legal = PDRectangle(0, 0, 612, 1008);

  /// A rectangle the size of A0 Paper.
  static final PDRectangle a0 = PDRectangle(0, 0, 2383.937, 3370.3937);

  /// A rectangle the size of A1 Paper.
  static final PDRectangle a1 = PDRectangle(0, 0, 1683.7795, 2383.937);

  /// A rectangle the size of A2 Paper.
  static final PDRectangle a2 = PDRectangle(0, 0, 1190.5513, 1683.7795);

  /// A rectangle the size of A3 Paper.
  static final PDRectangle a3 = PDRectangle(0, 0, 841.8898, 1190.5513);

  /// A rectangle the size of A4 Paper.
  static final PDRectangle a4 = PDRectangle(0, 0, 595.2756, 841.8898);

  /// A rectangle the size of A5 Paper.
  static final PDRectangle a5 = PDRectangle(0, 0, 419.5276, 595.2756);

  /// A rectangle the size of A6 Paper.
  static final PDRectangle a6 = PDRectangle(0, 0, 297.6378, 419.5276);

  double get width => upperRightX - lowerLeftX;

  double get height => upperRightY - lowerLeftY;

  COSArray toCOSArray() {
    final array = COSArray();
    array.add(COSFloat(lowerLeftX));
    array.add(COSFloat(lowerLeftY));
    array.add(COSFloat(upperRightX));
    array.add(COSFloat(upperRightY));
    return array;
  }

  static double _toDouble(COSBase base) {
    if (base is COSNumber) {
      return base.doubleValue;
    }
    throw ArgumentError(
        'Rectangle elements must be numbers, got ${base.runtimeType}');
  }

  @override
  String toString() =>
      'PDRectangle($lowerLeftX, $lowerLeftY, $upperRightX, $upperRightY)';

  @override
  bool operator ==(Object other) {
    return other is PDRectangle &&
        other.lowerLeftX == lowerLeftX &&
        other.lowerLeftY == lowerLeftY &&
        other.upperRightX == upperRightX &&
        other.upperRightY == upperRightY;
  }

  @override
  int get hashCode =>
      Object.hash(lowerLeftX, lowerLeftY, upperRightX, upperRightY);
}

