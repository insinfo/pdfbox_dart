import 'package:pdfbox_dart/src/fontbox/ttf/table/fvar/font_variation_axis.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:test/test.dart';

void main() {
  group('TrueTypeFont variation axes', () {
    test('initialises coordinates when axes are updated', () {
      final font = TrueTypeFont();
      font.updateVariationAxes(const <FontVariationAxis>[
        FontVariationAxis(
          tag: 'wght',
          minValue: 100.0,
          defaultValue: 400.0,
          maxValue: 900.0,
          flags: 0,
          axisNameId: 0,
        ),
        FontVariationAxis(
          tag: 'wdth',
          minValue: 75.0,
          defaultValue: 100.0,
          maxValue: 125.0,
          flags: 0,
          axisNameId: 0,
        ),
      ]);

      expect(font.variationAxes, hasLength(2));
      expect(font.normalizedVariationCoordinates, equals(<double>[0.0, 0.0]));
    });

    test('preserves coordinates by axis tag across refreshes', () {
      final font = TrueTypeFont();
      font.updateVariationAxes(const <FontVariationAxis>[
        FontVariationAxis(
          tag: 'wght',
          minValue: 100.0,
          defaultValue: 400.0,
          maxValue: 900.0,
          flags: 0,
          axisNameId: 0,
        ),
      ]);
      font.setVariationCoordinate('wght', 0.25);

      font.updateVariationAxes(const <FontVariationAxis>[
        FontVariationAxis(
          tag: 'wdth',
          minValue: 75.0,
          defaultValue: 100.0,
          maxValue: 125.0,
          flags: 0,
          axisNameId: 0,
        ),
        FontVariationAxis(
          tag: 'wght',
          minValue: 100.0,
          defaultValue: 400.0,
          maxValue: 900.0,
          flags: 0,
          axisNameId: 0,
        ),
      ]);

      expect(font.normalizedVariationCoordinates, equals(<double>[0.0, 0.25]));
    });

    test('setVariationCoordinates pads or truncates as needed', () {
      final font = TrueTypeFont();
      font.updateVariationAxes(const <FontVariationAxis>[
        FontVariationAxis(
          tag: 'wght',
          minValue: 100.0,
          defaultValue: 400.0,
          maxValue: 900.0,
          flags: 0,
          axisNameId: 0,
        ),
        FontVariationAxis(
          tag: 'wdth',
          minValue: 75.0,
          defaultValue: 100.0,
          maxValue: 125.0,
          flags: 0,
          axisNameId: 0,
        ),
        FontVariationAxis(
          tag: 'slnt',
          minValue: -10.0,
          defaultValue: 0.0,
          maxValue: 0.0,
          flags: 0,
          axisNameId: 0,
        ),
      ]);

      font.setVariationCoordinates(<double>[0.1]);
      expect(
          font.normalizedVariationCoordinates, equals(<double>[0.1, 0.0, 0.0]));

      font.setVariationCoordinates(<double>[0.2, 0.3, 0.4, 0.5]);
      expect(
          font.normalizedVariationCoordinates, equals(<double>[0.2, 0.3, 0.4]));
    });
  });
}
