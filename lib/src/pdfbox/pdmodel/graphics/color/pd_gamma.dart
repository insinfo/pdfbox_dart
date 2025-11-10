import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_number.dart';

/// Represents a gamma array used for color calibration.
class PDGamma implements COSObjectable {
  /// Constructs a gamma triple with all components set to zero.
  PDGamma()
      : _values = COSArray()
          ..add(COSFloat(0))
          ..add(COSFloat(0))
          ..add(COSFloat(0));

  /// Wraps an existing COS array.
  PDGamma.fromCOSArray(COSArray array) : _values = array;

  final COSArray _values;

  @override
  COSBase get cosObject => _values;

  /// Returns the underlying COS array.
  COSArray get cosArray => _values;

  double get r => (_values[0] as COSNumber).doubleValue;

  set r(double value) => _values[0] = COSFloat(value);

  double get g => (_values[1] as COSNumber).doubleValue;

  set g(double value) => _values[1] = COSFloat(value);

  double get b => (_values[2] as COSNumber).doubleValue;

  set b(double value) => _values[2] = COSFloat(value);
}
