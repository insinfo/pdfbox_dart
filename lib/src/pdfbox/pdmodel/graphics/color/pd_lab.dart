import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_range.dart';
import 'pd_cie_dictionary_based_color_space.dart';
import 'pd_color.dart';

class PDLab extends PDCIEDictionaryBasedColorSpace {
  PDLab() : this.fromCOSArray(_createArray());

  PDLab.fromCOSArray(COSArray array) : super(array);

  PDColor? _initialColor;

  @override
  String get name => COSName.lab.name;

  @override
  int get numberOfComponents => 3;

  @override
  List<double> getDefaultDecode(int bitsPerComponent) {
    final a = getARange();
    final b = getBRange();
    return [0.0, 100.0, a.min, a.max, b.min, b.max];
  }

  @override
  PDColor getInitialColor() {
    _initialColor ??= PDColor(
      [
        0.0,
        getARange().min.clamp(0, double.infinity).toDouble(),
        getBRange().min.clamp(0, double.infinity).toDouble(),
      ],
      this,
    );
    return _initialColor!;
  }

  @override
  List<double> toRGB(List<double> value) {
    final lStar = (value[0] + 16.0) / 116.0;
    final a = value.length > 1 ? value[1] : 0.0;
    final b = value.length > 2 ? value[2] : 0.0;
    final white = whitePoint;
    final x = white.x * _inverse(lStar + a / 500.0);
    final y = white.y * _inverse(lStar);
    final z = white.z * _inverse(lStar - b / 200.0);
    return xyzToRgb(x, y, z);
  }

  PDRange getARange() {
    final array = dictionary.getCOSArray(COSName.range);
    if (array != null && array.length >= 2) {
      return PDRange.fromCOSArray(array, 0);
    }
    return PDRange(-100.0, 100.0);
  }

  PDRange getBRange() {
    final array = dictionary.getCOSArray(COSName.range);
    if (array != null && array.length >= 4) {
      return PDRange.fromCOSArray(array, 2);
    }
    return PDRange(-100.0, 100.0);
  }

  void setARange(PDRange? range) {
    _setComponentRange(range, 0);
  }

  void setBRange(PDRange? range) {
    _setComponentRange(range, 2);
  }

  void _setComponentRange(PDRange? range, int offset) {
    final array = dictionary.getCOSArray(COSName.range) ?? _defaultRangeArray();
    if (range == null) {
      array[offset] = COSFloat(-100);
      array[offset + 1] = COSFloat(100);
    } else {
      array[offset] = COSFloat(range.min);
      array[offset + 1] = COSFloat(range.max);
    }
    dictionary[COSName.range] = array;
    _initialColor = null;
  }

  double _inverse(double value) {
    const threshold = 6.0 / 29.0;
    if (value > threshold) {
      return value * value * value;
    }
    return (108.0 / 841.0) * (value - (4.0 / 29.0));
  }

  static COSArray _createArray() {
    final array = COSArray();
    array.add(COSName.lab);
    array.add(COSDictionary());
    return array;
  }

  COSArray _defaultRangeArray() {
    final range = COSArray();
    range.add(COSFloat(-100));
    range.add(COSFloat(100));
    range.add(COSFloat(-100));
    range.add(COSFloat(100));
    return range;
  }
}
