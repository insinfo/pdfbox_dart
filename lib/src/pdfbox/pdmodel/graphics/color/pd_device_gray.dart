import 'pd_color.dart';
import 'pd_color_space.dart';

/// DeviceGray colour space (single component intensity).
class PDDeviceGray extends PDDeviceColorSpace {
  PDDeviceGray._();

  /// Shared singleton instance matching PDFBox behaviour.
  static final PDDeviceGray instance = PDDeviceGray._();

  @override
  String get name => 'DeviceGray';

  @override
  int get numberOfComponents => 1;

  @override
  List<double> getDefaultDecode(int bitsPerComponent) =>
      const <double>[0.0, 1.0];

  @override
  PDColor getInitialColor() => PDColor(const <double>[0.0], this);

  @override
  List<double> toRGB(List<double> value) {
    final gray = _clamp(value.isEmpty ? 0.0 : value[0]);
    return <double>[gray, gray, gray];
  }

  double _clamp(double component) {
    if (component <= 0.0) {
      return 0.0;
    }
    if (component >= 1.0) {
      return 1.0;
    }
    return component;
  }
}
