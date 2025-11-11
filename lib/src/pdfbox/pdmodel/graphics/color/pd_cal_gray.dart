import 'dart:math' as math;

import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import 'pd_cie_dictionary_based_color_space.dart';
import 'pd_color.dart';

class PDCalGray extends PDCIEDictionaryBasedColorSpace {
  PDCalGray() : this.fromCOSArray(_createArray());

  PDCalGray.fromCOSArray(COSArray array)
      : _rgbCache = <double, List<double>>{},
        super(array) {
    _initialColor = PDColor([0.0], this);
  }

  late final PDColor _initialColor;
  final Map<double, List<double>> _rgbCache;

  @override
  String get name => COSName.calGray.name;

  @override
  int get numberOfComponents => 1;

  double get gamma => dictionary.getFloat(COSName.gamma) ?? 1.0;

  set gamma(double value) => dictionary[COSName.gamma] = COSFloat(value);

  @override
  List<double> getDefaultDecode(int bitsPerComponent) => const [0.0, 1.0];

  @override
  PDColor getInitialColor() => _initialColor;

  @override
  List<double> toRGB(List<double> value) {
    final component = value.isNotEmpty ? value[0] : 0.0;
    final normalized = component.clamp(0.0, 1.0).toDouble();
    if (hasDefaultWhitePoint) {
      final cached = _rgbCache[normalized];
      if (cached != null) {
        return List<double>.from(cached, growable: false);
      }
      final exponent = gamma;
      final powValue = exponent == 1.0
          ? normalized
          : math.pow(normalized, exponent).toDouble();
      final rgb = xyzToRgb(powValue, powValue, powValue);
      _rgbCache[normalized] = List<double>.from(rgb, growable: false);
      return rgb;
    }
    return [normalized, normalized, normalized];
  }

  static COSArray _createArray() {
    final array = COSArray();
    array.add(COSName.calGray);
    array.add(COSDictionary());
    return array;
  }
}
