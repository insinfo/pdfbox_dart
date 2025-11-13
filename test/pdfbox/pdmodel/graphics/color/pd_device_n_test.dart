import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_device_n.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_device_rgb.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_raster.dart';
import 'package:test/test.dart';

void main() {
  group('PDDeviceN', () {
    test('evaluates tint transform fallback', () {
      final tintTransform = _buildTintFunction();
      final deviceNArray = COSArray()
        ..add(COSName.deviceN)
        ..add(_colorantNames(<String>['Cyan', 'Magenta']))
        ..add(COSName.deviceRGB)
        ..add(tintTransform);

      final deviceN = PDDeviceN.fromCOSArray(deviceNArray);

      expect(deviceN.numberOfComponents, 2);
      expect(deviceN.alternateColorSpace, same(PDDeviceRGB.instance));
      expect(deviceN.colorantNames,
          orderedEquals(const <String>['Cyan', 'Magenta']));

      expect(
        deviceN.toRGB(const <double>[0.0, 0.0]),
        orderedEquals(const <double>[0.0, 0.0, 0.0]),
      );
      expect(
        deviceN.toRGB(const <double>[1.0, 0.0]),
        orderedEquals(const <double>[1.0, 0.0, 0.0]),
      );
      expect(
        deviceN.toRGB(const <double>[0.0, 1.0]),
        orderedEquals(const <double>[0.0, 1.0, 0.0]),
      );
      expect(
        deviceN.toRGB(const <double>[1.0, 1.0]),
        orderedEquals(const <double>[1.0, 1.0, 0.0]),
      );

      final mixed = deviceN.toRGB(const <double>[0.5, 0.5]);
      expect(mixed[0], closeTo(0.5, 1e-6));
      expect(mixed[1], closeTo(0.5, 1e-6));
      expect(mixed[2], closeTo(0.0, 1e-6));

      final repeated = deviceN.toRGB(const <double>[0.5, 0.5]);
      expect(repeated, isNot(same(mixed)));
      expect(repeated, orderedEquals(mixed));
    });

    test('applies attributes process and spot colorants', () {
      final tintTransform = _buildTintFunction();
      final attributes = _buildDeviceNAttributes();

      final deviceNArray = COSArray()
        ..add(COSName.deviceN)
        ..add(_colorantNames(<String>['Cyan', 'SpotOrange']))
        ..add(COSName.deviceRGB)
        ..add(tintTransform)
        ..add(attributes);

      final deviceN = PDDeviceN.fromCOSArray(deviceNArray);

      final rgb = deviceN.toRGB(const <double>[0.25, 0.5]);
      expect(rgb[0], closeTo(0.45, 1e-6));
      expect(rgb[1], closeTo(0.7, 1e-6));
      expect(rgb[2], closeTo(0.8, 1e-6));

      final processOnly = deviceN.toRGB(const <double>[0.25, 0.0]);
      expect(processOnly[0], closeTo(0.75, 1e-6));
      expect(processOnly[1], closeTo(1.0, 1e-6));
      expect(processOnly[2], closeTo(1.0, 1e-6));
    });

    test('falls back to tint transform when process mapping missing', () {
      final tintTransform = _buildTintFunction();
      final attributes = _buildDeviceNAttributes(includeSpot: false);

      final withAttributes = COSArray()
        ..add(COSName.deviceN)
        ..add(_colorantNames(<String>['SpotBlue']))
        ..add(COSName.deviceRGB)
        ..add(tintTransform)
        ..add(attributes);

      final withoutAttributes = COSArray()
        ..add(COSName.deviceN)
        ..add(_colorantNames(<String>['SpotBlue']))
        ..add(COSName.deviceRGB)
        ..add(tintTransform);

      final deviceNWithAttributes = PDDeviceN.fromCOSArray(withAttributes);
      final deviceNWithoutAttributes =
          PDDeviceN.fromCOSArray(withoutAttributes);

      final expected = deviceNWithoutAttributes.toRGB(const <double>[0.5]);
      final actual = deviceNWithAttributes.toRGB(const <double>[0.5]);

      expect(actual, orderedEquals(expected));
    });

    test('renders raster using attributes cache', () {
      final tintTransform = _buildTintFunction();
      final attributes = _buildDeviceNAttributes();

      final deviceNArray = COSArray()
        ..add(COSName.deviceN)
        ..add(_colorantNames(<String>['Cyan', 'SpotOrange']))
        ..add(COSName.deviceRGB)
        ..add(tintTransform)
        ..add(attributes);

      final deviceN = PDDeviceN.fromCOSArray(deviceNArray);

      final raster = PDRaster.fromBytes(
        width: 2,
        height: 1,
        componentsPerPixel: 2,
        bytes: Uint8List.fromList(<int>[64, 128, 191, 64]),
      );

      final image = deviceN.toRGBImage(raster);
      expect(image.width, 2);
      expect(image.height, 1);

      final expectedFirst =
          _rgbBytes(deviceN.toRGB(<double>[64 / 255, 128 / 255]));
      final expectedSecond =
          _rgbBytes(deviceN.toRGB(<double>[191 / 255, 64 / 255]));

      final firstPixel = image.getPixel(0, 0);
      expect(firstPixel.r, equals(expectedFirst[0]));
      expect(firstPixel.g, equals(expectedFirst[1]));
      expect(firstPixel.b, equals(expectedFirst[2]));

      final secondPixel = image.getPixel(1, 0);
      expect(secondPixel.r, equals(expectedSecond[0]));
      expect(secondPixel.g, equals(expectedSecond[1]));
      expect(secondPixel.b, equals(expectedSecond[2]));
    });
  });
}

COSArray _colorantNames(List<String> names) {
  final array = COSArray();
  for (final name in names) {
    array.add(COSName.get(name));
  }
  return array;
}

COSStream _buildTintFunction() {
  final stream = COSStream()
    ..setInt(COSName.functionType, 0)
    ..setItem(COSName.domain, _floatArray(<double>[0.0, 1.0, 0.0, 1.0]))
    ..setItem(
        COSName.range, _floatArray(<double>[0.0, 1.0, 0.0, 1.0, 0.0, 1.0]))
    ..setItem(
      COSName.size,
      COSArray()
        ..add(COSInteger(2))
        ..add(COSInteger(2)),
    )
    ..setInt(COSName.bitsPerSample, 8)
    ..data = Uint8List.fromList(
      <int>[0, 0, 0, 255, 0, 0, 0, 255, 0, 255, 255, 0],
    );
  return stream;
}

COSArray _floatArray(List<double> values) {
  final array = COSArray();
  for (final value in values) {
    array.add(COSFloat(value));
  }
  return array;
}

COSDictionary _buildDeviceNAttributes({bool includeSpot = true}) {
  final processDict = COSDictionary()
    ..setItem(COSName.colorSpace, COSName.deviceCMYK)
    ..setItem(
      COSName.components,
      COSArray()
        ..add(COSName.get('Cyan'))
        ..add(COSName.get('Magenta'))
        ..add(COSName.get('Yellow'))
        ..add(COSName.get('Black')),
    );

  final attributes = COSDictionary()..setItem(COSName.process, processDict);

  if (includeSpot) {
    attributes.setItem(
      COSName.colorants,
      COSDictionary()
        ..setItem(
          COSName.get('SpotOrange'),
          _buildSeparationSpace('SpotOrange'),
        ),
    );
  }

  return attributes;
}

COSArray _buildSeparationSpace(String name) {
  return COSArray()
    ..add(COSName.separation)
    ..add(COSName.get(name))
    ..add(COSName.deviceRGB)
    ..add(_type2Function(
      c0: const <double>[1.0, 1.0, 1.0],
      c1: const <double>[0.2, 0.4, 0.6],
    ));
}

COSDictionary _type2Function({
  required List<double> c0,
  required List<double> c1,
  double exponent = 1.0,
}) {
  return COSDictionary()
    ..setInt(COSName.functionType, 2)
    ..setItem(COSName.domain, _floatArray(const <double>[0.0, 1.0]))
    ..setItem(
      COSName.range,
      _floatArray(const <double>[
        0.0,
        1.0,
        0.0,
        1.0,
        0.0,
        1.0,
      ]),
    )
    ..setItem(COSName.c0, _floatArray(c0))
    ..setItem(COSName.c1, _floatArray(c1))
    ..setItem(COSName.n, COSFloat(exponent));
}

List<int> _rgbBytes(List<double> rgb) {
  final r = (rgb[0].clamp(0.0, 1.0) * 255).round();
  final g = (rgb[1].clamp(0.0, 1.0) * 255).round();
  final b = (rgb[2].clamp(0.0, 1.0) * 255).round();
  return <int>[r, g, b];
}
