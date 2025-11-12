import '../../../cos/cos_base.dart';
import '../../../util/matrix.dart';
import '../../graphics/color/pd_color.dart';
import '../../graphics/color/pd_color_space.dart';
import '../../graphics/color/pd_device_gray.dart';
import '../../graphics/pd_line_dash_pattern.dart';
import '../blend/blend_mode.dart';
import 'pd_soft_mask.dart';
import 'pd_text_state.dart';
import 'rendering_intent.dart';

/// Represents the active graphics state while processing a content stream.
class PDGraphicsState {
  PDGraphicsState()
      : currentTransformationMatrix = Matrix(),
        strokingColorSpace = PDDeviceGray.instance,
        nonStrokingColorSpace = PDDeviceGray.instance,
        strokingColor = PDDeviceGray.instance.getInitialColor(),
        nonStrokingColor = PDDeviceGray.instance.getInitialColor();

  Matrix currentTransformationMatrix;
  PDColor strokingColor;
  PDColor nonStrokingColor;
  PDColorSpace strokingColorSpace;
  PDColorSpace nonStrokingColorSpace;
  PDTextState textState = PDTextState();
  double lineWidth = 1.0;
  int lineCap = 0;
  int lineJoin = 0;
  double miterLimit = 10.0;
  PDLineDashPattern lineDashPattern = PDLineDashPattern();
  RenderingIntent? renderingIntent;
  bool strokeAdjustment = false;
  BlendMode blendMode = BlendMode.normal;
  PDSoftMask? softMask;
  double alphaConstant = 1.0;
  double nonStrokingAlphaConstant = 1.0;
  bool alphaSource = false;
  bool overprint = false;
  bool nonStrokingOverprint = false;
  int overprintMode = 0;
  COSBase? transfer;
  double flatness = 1.0;
  double smoothness = 0.0;
  Matrix? textMatrix;
  Matrix? textLineMatrix;

  /// Produces a deep copy of this graphics state.
  PDGraphicsState clone() {
    final copy = PDGraphicsState();
    copy.currentTransformationMatrix = currentTransformationMatrix.clone();
    copy.strokingColor = PDColor(strokingColor.components, strokingColor.colorSpace);
    copy.nonStrokingColor =
        PDColor(nonStrokingColor.components, nonStrokingColor.colorSpace);
    copy.strokingColorSpace = strokingColorSpace;
    copy.nonStrokingColorSpace = nonStrokingColorSpace;
    copy.textState = textState.clone();
    copy.lineWidth = lineWidth;
    copy.lineCap = lineCap;
    copy.lineJoin = lineJoin;
    copy.miterLimit = miterLimit;
    copy.lineDashPattern =
        PDLineDashPattern.fromValues(lineDashPattern.dashArray, lineDashPattern.phase);
    copy.renderingIntent = renderingIntent;
    copy.strokeAdjustment = strokeAdjustment;
    copy.blendMode = blendMode;
    copy.softMask = softMask;
    copy.alphaConstant = alphaConstant;
    copy.nonStrokingAlphaConstant = nonStrokingAlphaConstant;
    copy.alphaSource = alphaSource;
    copy.overprint = overprint;
    copy.nonStrokingOverprint = nonStrokingOverprint;
    copy.overprintMode = overprintMode;
    copy.transfer = transfer;
    copy.flatness = flatness;
    copy.smoothness = smoothness;
    copy.textMatrix = textMatrix?.clone();
    copy.textLineMatrix = textLineMatrix?.clone();
    return copy;
  }

  void setLineDashPattern(PDLineDashPattern pattern) {
    lineDashPattern = pattern;
  }

  void setRenderingIntent(RenderingIntent? intent) {
    renderingIntent = intent;
  }

  void setSoftMask(PDSoftMask? mask) {
    softMask = mask;
  }
}
