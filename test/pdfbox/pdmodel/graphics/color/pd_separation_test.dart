import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_device_rgb.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_separation.dart';
import 'package:test/test.dart';

void main() {
  group('PDSeparation', () {
    test('converts tint to alternate RGB components', () {
      final tintTransform = _buildTintTransform();
      final separationArray = COSArray()
        ..add(COSName.separation)
        ..add(COSName.get('SpotRed'))
        ..add(COSName.deviceRGB)
        ..add(tintTransform);

      final separation = PDSeparation.fromCOSArray(separationArray);

      expect(separation.colorantName, 'SpotRed');
      expect(separation.alternateColorSpace, same(PDDeviceRGB.instance));

      final initial = separation.getInitialColor();
      expect(initial.components.single, closeTo(1.0, 1e-6));

      expect(
        separation.toRGB(const <double>[0.0]),
        orderedEquals(const <double>[0.0, 0.0, 0.0]),
      );
      expect(
        separation.toRGB(const <double>[1.0]),
        orderedEquals(const <double>[1.0, 0.0, 0.0]),
      );

      final mid = separation.toRGB(const <double>[0.5]);
      expect(mid[0], closeTo(0.5, 1e-6));
      expect(mid[1], closeTo(0.0, 1e-6));
      expect(mid[2], closeTo(0.0, 1e-6));

      final another = separation.toRGB(const <double>[0.5]);
      expect(another, isNot(same(mid)));
      expect(another, orderedEquals(mid));
    });
  });
}

COSStream _buildTintTransform() {
  final stream = COSStream()
    ..setInt(COSName.functionType, 0)
    ..setItem(COSName.domain, _floatArray(<double>[0.0, 1.0]))
    ..setItem(
        COSName.range, _floatArray(<double>[0.0, 1.0, 0.0, 1.0, 0.0, 1.0]))
    ..setItem(COSName.size, COSArray()..add(COSInteger(2)))
    ..setInt(COSName.bitsPerSample, 8)
    ..data = Uint8List.fromList(<int>[0, 0, 0, 255, 0, 0]);
  return stream;
}

COSArray _floatArray(List<double> values) {
  final array = COSArray();
  for (final value in values) {
    array.add(COSFloat(value));
  }
  return array;
}
