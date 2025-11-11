import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_raster.dart';
import 'package:test/test.dart';

void main() {
  group('PDRaster', () {
    test('normalises 8-bit samples to unit doubles', () {
      final raster = PDRaster.fromBytes(
        width: 1,
        height: 1,
        componentsPerPixel: 3,
        bytes: Uint8List.fromList(<int>[0, 128, 255]),
      );
      final components = List<double>.filled(3, 0.0);
      raster.getPixel(0, 0, components);
      expect(components[0], equals(0.0));
      expect(components[1], closeTo(128 / 255, 1e-9));
      expect(components[2], equals(1.0));
    });

    test('exports component bytes', () {
      final raster = PDRaster(
        width: 2,
        height: 1,
        componentsPerPixel: 2,
        samples: const <double>[0.1, 0.5, 0.9, 0.0],
      );
      final components = List<int>.filled(2, 0);
      raster.getPixelBytes(1, 0, components);
      expect(components, equals(<int>[230, 0]));
    });
  });
}
