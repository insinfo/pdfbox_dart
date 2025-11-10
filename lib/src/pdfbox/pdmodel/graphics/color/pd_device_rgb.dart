import 'pd_color.dart';
import 'pd_color_space.dart';

/// DeviceRGB colour space used by most PDF content streams.
class PDDeviceRGB extends PDDeviceColorSpace {
  PDDeviceRGB._();

  /// Shared singleton instance.
  static final PDDeviceRGB instance = PDDeviceRGB._();

  @override
  String get name => 'DeviceRGB';

  @override
  int get numberOfComponents => 3;

  @override
  List<double> getDefaultDecode(int bitsPerComponent) =>
      const <double>[0.0, 1.0, 0.0, 1.0, 0.0, 1.0];

  @override
  PDColor getInitialColor() => PDColor(const <double>[0.0, 0.0, 0.0], this);

  @override
  List<double> toRGB(List<double> value) {
    final normalized = normalizeComponents(value);
    return <double>[
      _clamp(normalized[0]),
      _clamp(normalized[1]),
      _clamp(normalized[2]),
    ];
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
