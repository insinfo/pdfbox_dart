import '../../../cos/cos_base.dart';
import '../../../cos/cos_name.dart';

import 'pd_color.dart';

/// Base contract for color spaces used by the PDF graphics model.
abstract class PDColorSpace implements COSObjectable {
  /// Returns the PDF name of this color space.
  String get name;

  /// Returns the number of components required by this color space.
  int get numberOfComponents;

  /// Returns the default decode array for the given component precision.
  List<double> getDefaultDecode(int bitsPerComponent);

  /// Returns the initial color defined by the color space.
  PDColor getInitialColor();

  /// Converts the given component array to an RGB triple scaled to 0..1.
  List<double> toRGB(List<double> value);

  /// Ensures the provided [components] list matches the component count by
  /// trimming or padding with zero values.
  List<double> normalizeComponents(Iterable<double> components) {
    final normalized = List<double>.filled(numberOfComponents, 0.0);
    var index = 0;
    for (final component in components) {
      if (index >= normalized.length) {
        break;
      }
      normalized[index] = component;
      index++;
    }
    return normalized;
  }
}

/// Device colour spaces directly specify colours without profiles.
abstract class PDDeviceColorSpace extends PDColorSpace {
  @override
  COSBase get cosObject => COSName(name);

  @override
  String toString() => name;
}
