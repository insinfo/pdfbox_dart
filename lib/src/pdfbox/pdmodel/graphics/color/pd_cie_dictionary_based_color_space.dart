import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_number.dart';
import '../../../cos/cos_object.dart';
import '../../common/pd_range.dart';
import 'pd_color_math.dart';
import 'pd_color_space.dart';
import 'pd_tristimulus.dart';

/// Base class for CIE-based colour spaces backed by a dictionary.
abstract class PDCIEDictionaryBasedColorSpace extends PDColorSpace {
  PDCIEDictionaryBasedColorSpace(COSArray array)
      : _array = array,
        _dictionary = _ensureDictionary(array) {
    _whitePoint = _readWhitePoint();
  }

  final COSArray _array;
  final COSDictionary _dictionary;
  late PDTristimulus _whitePoint;

  @override
  COSBase get cosObject => _array;

  COSDictionary get dictionary => _dictionary;

  PDTristimulus get whitePoint => _whitePoint;

  set whitePoint(PDTristimulus value) {
    _whitePoint = value;
    _dictionary[COSName.whitePoint] = value.cosObject;
  }

  bool get hasDefaultWhitePoint =>
      _whitePoint.x == 1.0 && _whitePoint.y == 1.0 && _whitePoint.z == 1.0;

  PDTristimulus get blackPoint {
    final value = _dictionary.getDictionaryObject(COSName.blackPoint);
    if (value is COSArray) {
      return PDTristimulus.fromCOSArray(value);
    }
    return PDTristimulus();
  }

  set blackPoint(PDTristimulus value) {
    _dictionary[COSName.blackPoint] = value.cosObject;
  }

  double getGamma(COSName name) {
    final value = _dictionary.getDictionaryObject(name);
    if (value is COSNumber) {
      return value.doubleValue;
    }
    if (value is COSArray) {
      final numbers = value.toDoubleList();
      if (numbers.isNotEmpty) {
        return numbers.first;
      }
    }
    return 1.0;
  }

  void setGamma(COSName name, double gamma) {
    _dictionary[name] = COSFloat(gamma);
  }

  PDRange getRange(COSName name, int componentIndex,
      {double defaultMin = 0.0, double defaultMax = 1.0}) {
    final value = _dictionary.getDictionaryObject(name);
    if (value is COSArray) {
      final lower = value.getDouble(componentIndex * 2) ?? defaultMin;
      final upper = value.getDouble(componentIndex * 2 + 1) ?? defaultMax;
      return PDRange(lower, upper);
    }
    return PDRange(defaultMin, defaultMax);
  }

  /// Converts XYZ tristimulus values to RGB using the ICC default matrix.
  List<double> xyzToRgb(double x, double y, double z) {
    final r = PDColorMath.clampUnit(3.2406 * x - 1.5372 * y - 0.4986 * z);
    final g = PDColorMath.clampUnit(-0.9689 * x + 1.8758 * y + 0.0415 * z);
    final b = PDColorMath.clampUnit(0.0557 * x - 0.2040 * y + 1.0570 * z);
    return [r, g, b];
  }

  PDTristimulus _readWhitePoint() {
    final value = _dictionary.getDictionaryObject(COSName.whitePoint);
    if (value is COSArray) {
      return PDTristimulus.fromCOSArray(value);
    }
    final defaultWhite = PDTristimulus.fromComponents([1, 1, 1]);
    _dictionary[COSName.whitePoint] = defaultWhite.cosObject;
    return defaultWhite;
  }

  static COSDictionary _ensureDictionary(COSArray array) {
    if (array.isEmpty) {
      throw StateError('CIE colour space array must declare a name entry');
    }
    if (array.length >= 2) {
      final second = _resolve(array.getObject(1));
      if (second is COSDictionary) {
        return second;
      }
      final dictionary = COSDictionary();
      array[1] = dictionary;
      return dictionary;
    }
    final dictionary = COSDictionary();
    array.add(dictionary);
    return dictionary;
  }

  static COSBase _resolve(COSBase value) {
    if (value is COSObject) {
      return value.object;
    }
    return value;
  }
}
