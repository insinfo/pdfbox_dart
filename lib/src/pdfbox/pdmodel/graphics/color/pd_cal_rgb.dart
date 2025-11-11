import 'dart:math' as math;

import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import 'pd_cie_dictionary_based_color_space.dart';
import 'pd_color.dart';
import 'pd_gamma.dart';

class PDCalRGB extends PDCIEDictionaryBasedColorSpace {
  PDCalRGB() : this.fromCOSArray(_createArray());

  PDCalRGB.fromCOSArray(COSArray array) : super(array) {
    _initialColor = PDColor([0.0, 0.0, 0.0], this);
  }

  late final PDColor _initialColor;

  @override
  String get name => COSName.calRGB.name;

  @override
  int get numberOfComponents => 3;

  @override
  List<double> getDefaultDecode(int bitsPerComponent) =>
      const [0.0, 1.0, 0.0, 1.0, 0.0, 1.0];

  @override
  PDColor getInitialColor() => _initialColor;

  PDGamma get gamma {
    final existing = dictionary.getCOSArray(COSName.gamma);
    if (existing != null && existing.length >= 3) {
      return PDGamma.fromCOSArray(existing);
    }
    final array = COSArray()
      ..add(COSFloat(1))
      ..add(COSFloat(1))
      ..add(COSFloat(1));
    dictionary[COSName.gamma] = array;
    return PDGamma.fromCOSArray(array);
  }

  set gamma(PDGamma value) {
    dictionary[COSName.gamma] = value.cosObject;
  }

  List<double> get matrix {
    final values = dictionary.getCOSArray(COSName.matrix);
    if (values == null || values.length < 9) {
      return const [1, 0, 0, 0, 1, 0, 0, 0, 1];
    }
    return values.toDoubleList();
  }

  set matrix(List<double> values) {
    if (values.length != 9) {
      throw ArgumentError('CalRGB matrix must contain 9 entries');
    }
    final array = COSArray();
    for (final value in values) {
      array.add(COSFloat(value));
    }
    dictionary[COSName.matrix] = array;
  }

  @override
  List<double> toRGB(List<double> value) {
    if (hasDefaultWhitePoint) {
      final gammaValues = gamma;
      final a = _component(value, 0);
      final b = _component(value, 1);
      final c = _component(value, 2);
      final powA = math.pow(a, gammaValues.r).toDouble();
      final powB = math.pow(b, gammaValues.g).toDouble();
      final powC = math.pow(c, gammaValues.b).toDouble();
      final m = matrix;
      final x = m[0] * powA + m[3] * powB + m[6] * powC;
      final y = m[1] * powA + m[4] * powB + m[7] * powC;
      final z = m[2] * powA + m[5] * powB + m[8] * powC;
      return xyzToRgb(x, y, z);
    }
    return List<double>.from(value, growable: false);
  }

  static COSArray _createArray() {
    final array = COSArray();
    array.add(COSName.calRGB);
    array.add(COSDictionary());
    return array;
  }

  double _component(List<double> value, int index) {
    final raw = index < value.length ? value[index] : 0.0;
    return raw.clamp(0.0, 1.0).toDouble();
  }
}
