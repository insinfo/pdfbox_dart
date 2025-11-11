import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_number.dart';

/// Represents a rectangle in PDF coordinates.
class PDRectangle {
  const PDRectangle(
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

  final double lowerLeftX;
  final double lowerLeftY;
  final double upperRightX;
  final double upperRightY;

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
