import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_device_gray.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/state/pd_graphics_state.dart';
import 'package:test/test.dart';

void main() {
  test('clone creates independent copy', () {
    final state = PDGraphicsState()
      ..lineWidth = 3
      ..lineCap = 2
      ..alphaConstant = 0.5
      ..nonStrokingAlphaConstant = 0.4
      ..overprint = true
      ..strokingColor = PDDeviceGray.instance.getInitialColor();

    final clone = state.clone();

    state.lineWidth = 10;
    state.alphaConstant = 0.2;
    state.overprint = false;

    expect(clone.lineWidth, equals(3));
    expect(clone.alphaConstant, equals(0.5));
    expect(clone.overprint, isTrue);
    expect(clone.strokingColor.components,
        equals(PDDeviceGray.instance.getInitialColor().components));
  });
}
