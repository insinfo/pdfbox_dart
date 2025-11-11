import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_device_rgb.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_raster.dart';
import 'package:test/test.dart';

void main() {
  test('toRawImage preserves RGB samples', () {
    final raster = PDRaster.fromBytes(
      width: 2,
      height: 1,
      componentsPerPixel: 3,
      bytes: Uint8List.fromList(<int>[255, 0, 0, 16, 32, 64]),
    );

    final image = PDDeviceRGB.instance.toRawImage(raster);
    expect(image, isNotNull);
    final firstPixel = image!.getPixel(0, 0);
    expect(firstPixel.r, equals(255));
    expect(firstPixel.g, equals(0));
    expect(firstPixel.b, equals(0));

    final secondPixel = image.getPixel(1, 0);
    expect(secondPixel.r, equals(16));
    expect(secondPixel.g, equals(32));
    expect(secondPixel.b, equals(64));
  });
}
