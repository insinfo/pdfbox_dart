import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';
import '../../pd_resources.dart';
import 'pd_color.dart';
import 'pd_color_space.dart';
import 'pd_device_cmyk.dart';
import 'pd_device_gray.dart';
import 'pd_device_rgb.dart';

class PDICCBased extends PDColorSpace {
  PDICCBased({
    required COSArray array,
    required COSStream stream,
    required this.alternate,
  })  : _array = array,
        _stream = stream,
        _numberOfComponents =
            stream.getInt(COSName.n) ?? alternate.numberOfComponents;

  final COSArray _array;
  final COSStream _stream;
  final PDColorSpace alternate;
  final int _numberOfComponents;
  PDColor? _initialColor;

  @override
  String get name => COSName.iccBased.name;

  @override
  COSBase get cosObject => _array;

  @override
  int get numberOfComponents => _numberOfComponents;

  @override
  List<double> getDefaultDecode(int bitsPerComponent) {
    final range = _stream.getDictionaryObject(COSName.range);
    if (range is COSArray && range.length >= _numberOfComponents * 2) {
      return range.toDoubleList();
    }
    return alternate.getDefaultDecode(bitsPerComponent);
  }

  @override
  PDColor getInitialColor() {
    if (_initialColor != null) {
      return _initialColor!;
    }
    final components = List<double>.filled(numberOfComponents, 0.0);
    final range = _stream.getDictionaryObject(COSName.range);
    if (range is COSArray && range.length >= numberOfComponents * 2) {
      for (var i = 0; i < numberOfComponents; i++) {
        final min = range.getDouble(i * 2) ?? 0.0;
        components[i] = min > 0 ? min : 0.0;
      }
    }
    _initialColor = PDColor(components, this);
    return _initialColor!;
  }

  @override
  List<double> toRGB(List<double> value) => alternate.toRGB(value);

  PDColorSpace get alternateColorSpace => alternate;

  static PDICCBased fromArray(COSArray array, {PDResources? resources}) {
    if (array.length < 2) {
      throw StateError(
          'ICCBased colour space array must contain a stream entry');
    }
    final streamObject = array.getObject(1);
    if (streamObject is! COSStream) {
      throw StateError(
          'ICCBased colour space requires a COSStream as the second operand');
    }
    final alternateValue = streamObject.getDictionaryObject(COSName.alternate);
    final alternateColorSpace = alternateValue != null
        ? PDColorSpace.create(alternateValue, resources: resources)
        : _defaultAlternate(streamObject.getInt(COSName.n));
    return PDICCBased(
      array: array,
      stream: streamObject,
      alternate: alternateColorSpace,
    );
  }

  static PDColorSpace _defaultAlternate(int? componentCount) {
    switch (componentCount) {
      case 1:
        return PDDeviceGray.instance;
      case 4:
        return PDDeviceCMYK.instance;
      case 3:
      default:
        return PDDeviceRGB.instance;
    }
  }
}
