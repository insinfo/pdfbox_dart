import 'package:image/image.dart' as img;

import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_name.dart';

import 'pd_color.dart';
import 'pd_color_space.dart';
import 'pd_raster.dart';

/// Represents a Pattern color space, optionally paired with an underlying
/// colour space for uncoloured tiling patterns.
class PDPatternColorSpace extends PDColorSpace {
  PDPatternColorSpace({this.underlying});

  final PDColorSpace? underlying;

  @override
  String get name => 'Pattern';

  @override
  int get numberOfComponents => underlying?.numberOfComponents ?? 0;

  @override
  List<double> getDefaultDecode(int bitsPerComponent) =>
      underlying?.getDefaultDecode(bitsPerComponent) ?? const <double>[];

  @override
  PDColor getInitialColor() {
    if (underlying != null) {
      return PDColor(underlying!.getInitialColor().components, this);
    }
    return PDColor(const <double>[], this);
  }

  @override
  List<double> toRGB(List<double> value) {
    if (underlying != null) {
      return underlying!.toRGB(value);
    }
    // Without an underlying colour space we cannot derive RGB data. Return a
    // neutral value to avoid crashes in higher-level callers.
    return const <double>[0.0, 0.0, 0.0];
  }

  @override
  COSBase get cosObject {
    final array = COSArray();
    array.add(COSName.pattern);
    if (underlying != null) {
      array.addObject(underlying!.cosObject);
    }
    return array;
  }

  @override
  img.Image toRGBImage(PDRaster raster) {
    if (underlying == null) {
      throw UnsupportedError(
        'Cannot convert uncoloured Pattern space to RGB without underlying space.',
      );
    }
    return underlying!.toRGBImage(raster);
  }

  @override
  img.Image? toRawImage(PDRaster raster) => underlying?.toRawImage(raster);
}
