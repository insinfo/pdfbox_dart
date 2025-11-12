import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/blend/blend_mode.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/state/pd_extended_graphics_state.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/state/pd_graphics_state.dart';
import 'package:test/test.dart';

void main() {
  test('copyIntoGraphicsState applies dictionary values', () {
    final dict = COSDictionary()
      ..setFloat(COSName.lw, 2.5)
      ..setInt(COSName.lc, 1)
      ..setInt(COSName.lj, 2)
      ..setFloat(COSName.ml, 11.5)
      ..setItem(COSName.d, _dashPattern())
      ..setName(COSName.ri, 'Perceptual')
      ..setBoolean(COSName.op, true)
      ..setBoolean(COSName.opNs, false)
      ..setInt(COSName.opm, 1)
      ..setItem(COSName.font, _fontEntry(12.0))
      ..setFloat(COSName.fl, 0.6)
      ..setFloat(COSName.sm, 0.2)
      ..setBoolean(COSName.sa, true)
      ..setFloat(COSName.ca, 0.4)
      ..setFloat(COSName.caNs, 0.3)
      ..setBoolean(COSName.ais, true)
      ..setBoolean(COSName.tk, false)
      ..setItem(COSName.sMask, COSDictionary())
      ..setItem(COSName.bm, COSName.get('Multiply'))
      ..setItem(COSName.tr, COSName.identity)
      ..setItem(COSName.tr2, COSName.get('IdentityB'));

    final extGState = PDExtendedGraphicsState(dict);
    final graphicsState = PDGraphicsState();

    extGState.copyIntoGraphicsState(graphicsState);

    expect(graphicsState.lineWidth, closeTo(2.5, 1e-9));
    expect(graphicsState.lineCap, equals(1));
    expect(graphicsState.lineJoin, equals(2));
    expect(graphicsState.miterLimit, closeTo(11.5, 1e-9));
    expect(graphicsState.lineDashPattern.phase, equals(2));
    expect(graphicsState.lineDashPattern.dashArray, equals(<double>[3, 1]));
    expect(graphicsState.renderingIntent?.stringValue, equals('Perceptual'));
    expect(graphicsState.overprint, isTrue);
    expect(graphicsState.nonStrokingOverprint, isFalse);
    expect(graphicsState.overprintMode, equals(1));
    expect(graphicsState.textState.fontSize, closeTo(12.0, 1e-9));
    expect(graphicsState.flatness, closeTo(0.6, 1e-9));
    expect(graphicsState.smoothness, closeTo(0.2, 1e-9));
    expect(graphicsState.strokeAdjustment, isTrue);
    expect(graphicsState.alphaConstant, closeTo(0.4, 1e-9));
    expect(graphicsState.nonStrokingAlphaConstant, closeTo(0.3, 1e-9));
    expect(graphicsState.alphaSource, isTrue);
    expect(graphicsState.textState.knockoutFlag, isFalse);
    expect(graphicsState.softMask, isNotNull);
    expect(
      graphicsState.softMask!.getInitialTransformationMatrix()?.toList(),
      equals(graphicsState.currentTransformationMatrix.toList()),
    );
    expect(graphicsState.blendMode, equals(BlendMode.multiply));
    // TR2 takes precedence over TR.
    expect(graphicsState.transfer, equals(COSName.get('IdentityB')));
  });
}

COSArray _dashPattern() {
  final dash = COSArray()
    ..addObject(COSFloat(3))
    ..addObject(COSFloat(1));
  final array = COSArray()
    ..addObject(dash)
    ..addObject(COSInteger(2));
  return array;
}

COSArray _fontEntry(double size) {
  final array = COSArray()
    ..addObject(COSDictionary())
    ..addObject(COSFloat(size));
  return array;
}
