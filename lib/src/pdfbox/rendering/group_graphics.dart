import 'package:dart_graphics/dart_graphics.dart';

/// Graphics implementation for non-isolated transparency groups.
///
/// Port of PDFBox's `GroupGraphics`.
class GroupGraphics implements Graphics2D {
  final ImageBuffer groupImage;
  final ImageBuffer groupAlphaImage;
  final Graphics2D groupG2D;
  late final Graphics2D alphaG2D;

  GroupGraphics(this.groupImage, this.groupG2D)
      : groupAlphaImage = ImageBuffer(groupImage.width, groupImage.height) {
    alphaG2D = groupAlphaImage.newGraphics2D();
  }



  @override
  TransformQuality get imageRenderQuality => groupG2D.imageRenderQuality;
  @override
  set imageRenderQuality(TransformQuality v) {
    groupG2D.imageRenderQuality = v;
    alphaG2D.imageRenderQuality = v;
  }

  @override
  Affine get transform => groupG2D.transform;

  @override
  LineJoin get lineJoin => groupG2D.lineJoin;
  @override
  set lineJoin(LineJoin value) {
    groupG2D.lineJoin = value;
    alphaG2D.lineJoin = value;
  }

  @override
  LineCap get lineCap => groupG2D.lineCap;
  @override
  set lineCap(LineCap value) {
    groupG2D.lineCap = value;
    alphaG2D.lineCap = value;
  }

  @override
  double get lineWidth => groupG2D.lineWidth;
  @override
  set lineWidth(double value) {
    groupG2D.lineWidth = value;
    alphaG2D.lineWidth = value;
  }

  @override
  Color get strokeColor => groupG2D.strokeColor;
  @override
  set strokeColor(Color value) {
    groupG2D.strokeColor = value;
    alphaG2D.strokeColor = value;
  }

  @override
  Color get fillColor => groupG2D.fillColor;
  @override
  set fillColor(Color value) {
    groupG2D.fillColor = value;
    alphaG2D.fillColor = value;
  }

  @override
  double get masterAlpha => groupG2D.masterAlpha;
  @override
  set masterAlpha(double value) {
    groupG2D.masterAlpha = value;
    alphaG2D.masterAlpha = value;
  }

  @override
  double get antiAliasGamma => groupG2D.antiAliasGamma;
  @override
  set antiAliasGamma(double value) {
    groupG2D.antiAliasGamma = value;
    alphaG2D.antiAliasGamma = value;
  }

  @override
  double get miterLimit => groupG2D.miterLimit;
  @override
  set miterLimit(double value) {
    groupG2D.miterLimit = value;
    alphaG2D.miterLimit = value;
  }

  @override
  BlendMode get blendMode => groupG2D.blendMode;
  @override
  set blendMode(BlendMode value) {
    groupG2D.blendMode = value;
    alphaG2D.blendMode = value;
  }

  @override
  ImageFilter get imageFilter => groupG2D.imageFilter;
  @override
  set imageFilter(ImageFilter value) {
    groupG2D.imageFilter = value;
    alphaG2D.imageFilter = value;
  }

  @override
  ImageResample get imageResample => groupG2D.imageResample;
  @override
  set imageResample(ImageResample value) {
    groupG2D.imageResample = value;
    alphaG2D.imageResample = value;
  }

  @override
  GradientType get gradientType => groupG2D.gradientType;

  @override
  FillStyleType get fillStyleType => groupG2D.fillStyleType;

  @override
  Typeface? get typeface => groupG2D.typeface;
  @override
  set typeface(Typeface? value) {
    groupG2D.typeface = value;
    alphaG2D.typeface = value;
  }

  @override
  double get fontSize => groupG2D.fontSize;
  @override
  set fontSize(double value) {
    groupG2D.fontSize = value;
    alphaG2D.fontSize = value;
  }

  @override
  TextAlign get textAlign => groupG2D.textAlign;
  @override
  set textAlign(TextAlign value) {
    groupG2D.textAlign = value;
    alphaG2D.textAlign = value;
  }

  @override
  TextBaseline get textBaseline => groupG2D.textBaseline;
  @override
  set textBaseline(TextBaseline value) {
    groupG2D.textBaseline = value;
    alphaG2D.textBaseline = value;
  }

  @override
  int get width => groupG2D.width;
  @override
  int get height => groupG2D.height;

  @override
  void clear(Color color) {
    groupG2D.clear(color);
    alphaG2D.clear(color);
  }

  @override
  void renderPath(IVertexSource src, Color color) {
    groupG2D.renderPath(src, color);
    alphaG2D.renderPath(src, color);
  }

  @override
  void renderSpanPath(IVertexSource src, ISpanGenerator generator) {
    groupG2D.renderSpanPath(src, generator);
    alphaG2D.renderSpanPath(src, generator);
  }

  @override
  void renderGradientPath(IVertexSource src, SpanGradient gradient) {
    groupG2D.renderGradientPath(src, gradient);
    alphaG2D.renderGradientPath(src, gradient);
  }

  @override
  void save() {
    groupG2D.save();
    alphaG2D.save();
  }

  @override
  void restore() {
    groupG2D.restore();
    alphaG2D.restore();
  }

  @override
  void resetTransform() {
    groupG2D.resetTransform();
    alphaG2D.resetTransform();
  }

  @override
  void translate(double dx, double dy) {
    groupG2D.translate(dx, dy);
    alphaG2D.translate(dx, dy);
  }

  @override
  void scale(double sx, [double? sy]) {
    groupG2D.scale(sx, sy);
    alphaG2D.scale(sx, sy);
  }

  @override
  void rotate(double angle) {
    groupG2D.rotate(angle);
    alphaG2D.rotate(angle);
  }

  @override
  void skew(double sx, double sy) {
    groupG2D.skew(sx, sy);
    alphaG2D.skew(sx, sy);
  }

  @override
  void setTransform(Affine matrix) {
    groupG2D.setTransform(matrix);
    alphaG2D.setTransform(matrix);
  }

  @override
  void setSolidFill() {
    groupG2D.setSolidFill();
    alphaG2D.setSolidFill();
  }

  @override
  void setLinearGradient(double x1, double y1, double x2, double y2,
      List<({Color color, double offset})> stops) {
    groupG2D.setLinearGradient(x1, y1, x2, y2, stops);
    alphaG2D.setLinearGradient(x1, y1, x2, y2, stops);
  }

  @override
  void setRadialGradient(double cx, double cy, double radius,
      List<({Color color, double offset})> stops) {
    groupG2D.setRadialGradient(cx, cy, radius, stops);
    alphaG2D.setRadialGradient(cx, cy, radius, stops);
  }

  @override
  void clearGradientStops() {
    groupG2D.clearGradientStops();
    alphaG2D.clearGradientStops();
  }

  @override
  void addGradientStop(double offset, Color color) {
    groupG2D.addGradientStop(offset, color);
    alphaG2D.addGradientStop(offset, color);
  }

  @override
  void setPatternFill(IImageByte image,
      {DartGraphicsPatternRepetition repetition = DartGraphicsPatternRepetition.repeat,
      Affine? transform}) {
    groupG2D.setPatternFill(image,
        repetition: repetition, transform: transform);
    alphaG2D.setPatternFill(image,
        repetition: repetition, transform: transform);
  }

  @override
  void setPatternTransform(Affine transform) {
    groupG2D.setPatternTransform(transform);
    alphaG2D.setPatternTransform(transform);
  }

  @override
  void clearPattern() {
    groupG2D.clearPattern();
    alphaG2D.clearPattern();
  }

  @override
  void setFont(Typeface typeface, double pixelSize) {
    groupG2D.setFont(typeface, pixelSize);
    alphaG2D.setFont(typeface, pixelSize);
  }

  @override
  void drawTextCurrent(String text,
      {double x = 0, double y = 0, Color? color}) {
    groupG2D.drawTextCurrent(text, x: x, y: y, color: color);
    alphaG2D.drawTextCurrent(text, x: x, y: y, color: color);
  }

  @override
  VertexStorage get currentPath => groupG2D.currentPath;

  @override
  void beginPath() {
    groupG2D.beginPath();
    alphaG2D.beginPath();
  }

  @override
  void resetPath() {
    groupG2D.resetPath();
    alphaG2D.resetPath();
  }

  @override
  void moveTo(double x, double y) {
    groupG2D.moveTo(x, y);
    alphaG2D.moveTo(x, y);
  }

  @override
  void lineTo(double x, double y) {
    groupG2D.lineTo(x, y);
    alphaG2D.lineTo(x, y);
  }

  @override
  void curve3(double ctrlX, double ctrlY, double toX, double toY) {
    groupG2D.curve3(ctrlX, ctrlY, toX, toY);
    alphaG2D.curve3(ctrlX, ctrlY, toX, toY);
  }

  @override
  void curve4(double ctrl1X, double ctrl1Y, double ctrl2X, double ctrl2Y,
      double toX, double toY) {
    groupG2D.curve4(ctrl1X, ctrl1Y, ctrl2X, ctrl2Y, toX, toY);
    alphaG2D.curve4(ctrl1X, ctrl1Y, ctrl2X, ctrl2Y, toX, toY);
  }

  @override
  void closePath() {
    groupG2D.closePath();
    alphaG2D.closePath();
  }

  @override
  void rect(double x1, double y1, double x2, double y2) {
    groupG2D.rect(x1, y1, x2, y2);
    alphaG2D.rect(x1, y1, x2, y2);
  }

  @override
  void roundedRect(double x1, double y1, double x2, double y2,
      [double radius = 0]) {
    groupG2D.roundedRect(x1, y1, x2, y2, radius);
    alphaG2D.roundedRect(x1, y1, x2, y2, radius);
  }

  @override
  void ellipse(double cx, double cy, double rx, double ry,
      [int numSteps = 0, bool clockwise = false]) {
    groupG2D.ellipse(cx, cy, rx, ry, numSteps, clockwise);
    alphaG2D.ellipse(cx, cy, rx, ry, numSteps, clockwise);
  }

  @override
  void arc(double cx, double cy, double rx, double ry, double startAngle,
      double endAngle,
      [bool counterClockwise = false, int numSegments = 0]) {
    groupG2D.arc(cx, cy, rx, ry, startAngle, endAngle, counterClockwise,
        numSegments);
    alphaG2D.arc(cx, cy, rx, ry, startAngle, endAngle, counterClockwise,
        numSegments);
  }

  @override
  void drawPath([DrawPathFlag flag = DrawPathFlag.fillOnly]) {
    groupG2D.drawPath(flag);
    alphaG2D.drawPath(flag);
  }

  @override
  void drawImage(IImageByte image, double dx, double dy,
      [double? dWidth,
      double? dHeight,
      double? sx,
      double? sy,
      double? sWidth,
      double? sHeight]) {
    groupG2D.drawImage(
        image, dx, dy, dWidth, dHeight, sx, sy, sWidth, sHeight);
    alphaG2D.drawImage(
        image, dx, dy, dWidth, dHeight, sx, sy, sWidth, sHeight);
  }

  @override
  void fillPath({Color? colorOverride}) {
    groupG2D.fillPath(colorOverride: colorOverride);
    alphaG2D.fillPath(colorOverride: colorOverride);
  }

  @override
  void strokePath({Color? colorOverride}) {
    groupG2D.strokePath(colorOverride: colorOverride);
    alphaG2D.strokePath(colorOverride: colorOverride);
  }

  @override
  IVertexSource applyTransform(IVertexSource src) {
    return groupG2D.applyTransform(src);
  }

  @override
  void renderSvgString(String svgString,
      {double? viewBoxX,
      double? viewBoxY,
      double? viewBoxWidth,
      double? viewBoxHeight,
      bool flipY = false,
      Color? background}) {
    groupG2D.renderSvgString(svgString,
        viewBoxX: viewBoxX,
        viewBoxY: viewBoxY,
        viewBoxWidth: viewBoxWidth,
        viewBoxHeight: viewBoxHeight,
        flipY: flipY,
        background: background);
    alphaG2D.renderSvgString(svgString,
        viewBoxX: viewBoxX,
        viewBoxY: viewBoxY,
        viewBoxWidth: viewBoxWidth,
        viewBoxHeight: viewBoxHeight,
        flipY: flipY,
        background: background);
  }


  
  @override
  Color applyMasterAlpha(Color color) {
    // Delegate to one of them, assuming they stay in sync
    return groupG2D.applyMasterAlpha(color);
  }




  /// Computes backdrop removal.
  ///
  /// C = Cn + (Cn - C0) * (alpha0 / alphagn - alpha0)
  ///
  /// [backdrop] group backdrop
  /// [offsetX] backdrop left X coordinate
  /// [offsetY] backdrop upper Y coordinate
  void removeBackdrop(ImageBuffer backdrop, int offsetX, int offsetY) {
    final groupWidth = groupImage.width;
    final groupHeight = groupImage.height;
    final backdropWidth = backdrop.width;
    final backdropHeight = backdrop.height;

    final groupData = groupImage.getBuffer();
    final groupAlphaData = groupAlphaImage.getBuffer();
    final backdropData = backdrop.getBuffer();

    // 4 bytes per pixel (RGBA or BGRA depending on impl, dart_graphics uses standardized byte rendering mostly)
    // dart_graphics: ImageBuffer wraps Uint8List, usually RGBA 
    
    for (int y = 0; y < groupHeight; y++) {
      for (int x = 0; x < groupWidth; x++) {
        final index = (y * groupWidth + x) * 4;

        // alphagn is the total alpha of the group contents excluding backdrop.
        final alphagn = groupAlphaData[index + 3]; // Alpha at +3
        if (alphagn == 0) {
           groupData[index] = 0;
           groupData[index + 1] = 0;
           groupData[index + 2] = 0;
           groupData[index + 3] = 0;
           continue;
        }

        final backdropX = x + offsetX;
        final backdropY = y + offsetY;
        
        int r0 = 0;
        int g0 = 0;
        int b0 = 0;
        int alpha0 = 0;

        if (backdropX >= 0 &&
            backdropX < backdropWidth &&
            backdropY >= 0 &&
            backdropY < backdropHeight) {
           final bIndex = (backdropY * backdropWidth + backdropX) * 4;
           r0 = backdropData[bIndex];
           g0 = backdropData[bIndex + 1];
           b0 = backdropData[bIndex + 2];
           alpha0 = backdropData[bIndex + 3];
        } else {
           r0 = 0; g0 = 0; b0 = 0; alpha0 = 0;
        }

        // Alpha factor alpha0 / alphagn - alpha0 is in range 0.0-1.0.
        // float alpha0 / alphagn - alpha0 / 255.0f
        
        final floatAlpha0 = alpha0 / 255.0;
        final floatAlphagn = alphagn / 255.0;
        
        final alphaFactor = floatAlpha0 / floatAlphagn - floatAlpha0;
        
        // Group color
        final rn = groupData[index];
        final gn = groupData[index + 1];
        final bn = groupData[index + 2];
        
        int cR = _backdropRemoval(rn, r0, alphaFactor);
        int cG = _backdropRemoval(gn, g0, alphaFactor);
        int cB = _backdropRemoval(bn, b0, alphaFactor);
        
        groupData[index] = cR;
        groupData[index + 1] = cG;
        groupData[index + 2] = cB;
        groupData[index + 3] = alphagn;
      }
    }
  }

  int _backdropRemoval(int cn, int c0, double alphaFactor) {
    int c = (cn + (cn - c0) * alphaFactor).round();
    return c.clamp(0, 255);
  }
}
