import 'package:image/image.dart' as img;

import 'pd_color.dart';
import 'pd_color_math.dart';
import 'pd_color_space.dart';
import 'pd_raster.dart';

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
      PDColorMath.clampUnit(normalized[0]),
      PDColorMath.clampUnit(normalized[1]),
      PDColorMath.clampUnit(normalized[2]),
    ];
  }

  @override
  img.Image? toRawImage(PDRaster raster) {
    if (raster.componentsPerPixel != numberOfComponents) {
      return null;
    }
    final image = img.Image(width: raster.width, height: raster.height);
    final components = List<int>.filled(numberOfComponents, 0);
    for (var y = 0; y < raster.height; ++y) {
      for (var x = 0; x < raster.width; ++x) {
        raster.getPixelBytes(x, y, components);
        image.setPixelRgba(
            x, y, components[0], components[1], components[2], 255);
      }
    }
    return image;
  }
}
