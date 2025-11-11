import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_name.dart';
import '../../pd_resources.dart';
import '../../common/function/pdf_function.dart';
import 'pd_color.dart';
import 'pd_color_math.dart';
import 'pd_color_space.dart';
import 'pd_special_color_space.dart';

class PDSeparation extends PDSpecialColorSpace {
  PDSeparation._(this._array, this._alternateColorSpace, this._tintTransform) {
    _initialColor = PDColor(const [1.0], this);
  }

  factory PDSeparation.fromCOSArray(COSArray array, {PDResources? resources}) {
    if (array.length < 4) {
      throw StateError(
          'Separation colour space array must contain four elements');
    }
    final alternate = PDColorSpace.create(
      array.getObject(2),
      resources: resources,
    );
    final tintTransform = PDFunction.create(array.getObject(3));
    return PDSeparation._(array, alternate, tintTransform);
  }

  final COSArray _array;
  final PDColorSpace _alternateColorSpace;
  final PDFunction _tintTransform;
  late final PDColor _initialColor;
  final Map<int, List<double>> _rgbCache = <int, List<double>>{};

  @override
  COSBase get cosObject => _array;

  @override
  String get name => COSName.separation.name;

  @override
  int get numberOfComponents => 1;

  @override
  List<double> getDefaultDecode(int bitsPerComponent) => const [0.0, 1.0];

  @override
  PDColor getInitialColor() => _initialColor;

  PDColorSpace get alternateColorSpace => _alternateColorSpace;

  PDFunction get tintTransform => _tintTransform;

  String get colorantName {
    final name = _array.length > 1 ? _array.getObject(1) : null;
    if (name is COSName) {
      return name.name;
    }
    return '';
  }

  set colorantName(String value) {
    if (_array.length < 2) {
      _array.add(COSName(value));
    } else {
      _array[1] = COSName(value);
    }
  }

  @override
  List<double> toRGB(List<double> value) {
    final raw = value.isNotEmpty ? value[0] : 0.0;
    final normalized = PDColorMath.clampUnit(raw);
    final cacheKey = (normalized * 255).round();
    final cached = _rgbCache[cacheKey];
    if (cached != null) {
      return List<double>.from(cached, growable: false);
    }
    final evaluation = _tintTransform.eval(<double>[normalized]);
    final rgb = _alternateColorSpace.toRGB(evaluation);
    _rgbCache[cacheKey] = List<double>.from(rgb, growable: false);
    return rgb;
  }

  @override
  String toString() =>
      '${name}{"$colorantName" ${_alternateColorSpace.name} $tintTransform}';
}
