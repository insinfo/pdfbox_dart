import 'pd_color.dart';
import 'pd_color_math.dart';
import 'pd_color_space.dart';

/// DeviceCMYK colour space primarily used for print workflows.
class PDDeviceCMYK extends PDDeviceColorSpace {
  PDDeviceCMYK._();

  /// Shared singleton instance.
  static final PDDeviceCMYK instance = PDDeviceCMYK._();

  @override
  String get name => 'DeviceCMYK';

  @override
  int get numberOfComponents => 4;

  @override
  List<double> getDefaultDecode(int bitsPerComponent) => const <double>[
        0.0,
        1.0,
        0.0,
        1.0,
        0.0,
        1.0,
        0.0,
        1.0,
      ];

  @override
  PDColor getInitialColor() =>
      PDColor(const <double>[0.0, 0.0, 0.0, 1.0], this);

  @override
  List<double> toRGB(List<double> value) {
    final normalized = normalizeComponents(value);
    final c = PDColorMath.clampUnit(normalized[0]);
    final m = PDColorMath.clampUnit(normalized[1]);
    final y = PDColorMath.clampUnit(normalized[2]);
    final k = PDColorMath.clampUnit(normalized[3]);
    final r = (1.0 - c) * (1.0 - k);
    final g = (1.0 - m) * (1.0 - k);
    final b = (1.0 - y) * (1.0 - k);
    return <double>[r, g, b];
  }
}
