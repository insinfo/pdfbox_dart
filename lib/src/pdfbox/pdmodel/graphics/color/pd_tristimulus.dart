import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_number.dart';

/// Represents a tristimulus color value composed of X, Y, Z parameters.
class PDTristimulus implements COSObjectable {
  /// Constructs a tristimulus with components initialised to zero.
  PDTristimulus()
      : _values = COSArray()
          ..add(COSFloat(0))
          ..add(COSFloat(0))
          ..add(COSFloat(0));

  /// Wraps an existing COS array.
  PDTristimulus.fromCOSArray(COSArray array) : _values = array;

  /// Creates a tristimulus from raw XYZ components.
  PDTristimulus.fromComponents(Iterable<double> components)
      : _values = COSArray() {
    var index = 0;
    for (final component in components) {
      if (index >= 3) {
        break;
      }
      _values.add(COSFloat(component));
      index++;
    }
    while (_values.length < 3) {
      _values.add(COSFloat(0));
    }
  }

  final COSArray _values;

  @override
  COSBase get cosObject => _values;

  /// Returns the underlying COS array representation.
  COSArray get cosArray => _values;

  double get x => (_values[0] as COSNumber).doubleValue;

  set x(double value) => _values[0] = COSFloat(value);

  double get y => (_values[1] as COSNumber).doubleValue;

  set y(double value) => _values[1] = COSFloat(value);

  double get z => (_values[2] as COSNumber).doubleValue;

  set z(double value) => _values[2] = COSFloat(value);
}
