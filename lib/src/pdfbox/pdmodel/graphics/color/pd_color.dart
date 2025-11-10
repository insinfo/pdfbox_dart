import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_number.dart';

import 'pd_color_space.dart';

/// Represents a colour value within a [PDColorSpace].
class PDColor implements COSObjectable {
  /// Creates a colour instance using raw component values.
  PDColor(Iterable<double> components, this.colorSpace)
      : _components = List<double>.from(
            colorSpace.normalizeComponents(components),
            growable: false);

  /// Constructs a colour from a COS array.
  PDColor.fromCOSArray(COSArray array, this.colorSpace)
      : _components = colorSpace.normalizeComponents(
          array.map(_extractCosValue),
        ),
        _cosArray = array;

  final List<double> _components;
  final PDColorSpace colorSpace;
  COSArray? _cosArray;

  /// Returns an immutable view of the component array.
  List<double> get components =>
      List<double>.from(_components, growable: false);

  /// Converts this colour to the target RGB representation (0..1 components).
  List<double> toRGB() => colorSpace.toRGB(_components);

  @override
  COSBase get cosObject => _cosArray ??= _buildCOSArray();

  COSArray _buildCOSArray() {
    final array = COSArray();
    for (final component in _components) {
      array.add(COSFloat(component));
    }
    return array;
  }

  static double _extractCosValue(COSBase base) {
    if (base is COSNumber) {
      return base.doubleValue;
    }
    return 0.0;
  }
}
