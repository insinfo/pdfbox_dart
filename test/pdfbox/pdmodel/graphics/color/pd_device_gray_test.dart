import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_device_gray.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_raster.dart';
import 'package:test/test.dart';

void main() {
  test('toRawImage expands gray samples', () {
    final raster = PDRaster.fromBytes(
      width: 1,
      height: 2,
      componentsPerPixel: 1,
      bytes: Uint8List.fromList(<int>[32, 208]),
    );

    final image = PDDeviceGray.instance.toRawImage(raster);
    expect(image, isNotNull);

    final top = image!.getPixel(0, 0);
    expect(top.r, equals(32));
    expect(top.g, equals(32));
    expect(top.b, equals(32));

    final bottom = image.getPixel(0, 1);
    expect(bottom.r, equals(208));
    expect(bottom.g, equals(208));
    expect(bottom.b, equals(208));
  });
}
