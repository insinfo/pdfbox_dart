import 'package:image/image.dart' as img;

import 'pd_color.dart';
import 'pd_color_math.dart';
import 'pd_color_space.dart';
import 'pd_raster.dart';

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
    final gray = PDColorMath.clampUnit(value.isEmpty ? 0.0 : value[0]);
    return <double>[gray, gray, gray];
  }

  @override
  img.Image? toRawImage(PDRaster raster) {
    if (raster.componentsPerPixel != numberOfComponents) {
      return null;
    }
    final image = img.Image(width: raster.width, height: raster.height);
    final component = List<int>.filled(1, 0);
    for (var y = 0; y < raster.height; ++y) {
      for (var x = 0; x < raster.width; ++x) {
        raster.getPixelBytes(x, y, component);
        final gray = component[0];
        image.setPixelRgba(x, y, gray, gray, gray, 255);
      }
    }
    return image;
  }
}
