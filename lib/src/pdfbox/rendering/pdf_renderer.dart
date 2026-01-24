import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_graphics/dart_graphics.dart';
import 'package:dart_graphics/src/dart_graphics/image/png_encoder.dart';

import '../pdmodel/common/pd_rectangle.dart';
import '../pdmodel/pd_document.dart';
import '../pdmodel/pd_page.dart';
import '../util/matrix.dart';
import 'image_type.dart';
import 'page_drawer.dart';
import 'page_drawer_parameters.dart';
import 'render_destination.dart';

/// Port of PDFBox's `PDFRenderer`.
///
/// This renderer outputs a `dart_graphics` [ImageBuffer].
class PDFRenderer {
  PDFRenderer(this.document);

  final PDDocument document;

  bool _subsamplingAllowed = false;
  RenderDestination _defaultDestination = RenderDestination.view;
  Object? _renderingHints;
  double _imageDownscalingOptimizationThreshold = 0.5;

  bool isSubsamplingAllowed() => _subsamplingAllowed;

  void setSubsamplingAllowed(bool subsamplingAllowed) {
    _subsamplingAllowed = subsamplingAllowed;
  }

  RenderDestination getDefaultDestination() => _defaultDestination;

  void setDefaultDestination(RenderDestination destination) {
    _defaultDestination = destination;
  }

  Object? getRenderingHints() => _renderingHints;

  void setRenderingHints(Object? hints) {
    _renderingHints = hints;
  }

  double getImageDownscalingOptimizationThreshold() =>
      _imageDownscalingOptimizationThreshold;

  void setImageDownscalingOptimizationThreshold(double threshold) {
    _imageDownscalingOptimizationThreshold = threshold;
  }

  ImageBuffer renderImage(int pageIndex) {
    return renderImageWithScale(pageIndex, 1.0);
  }

  ImageBuffer renderImageWithDPI(int pageIndex, double dpi,
      [ImageType imageType = ImageType.RGB]) {
    return renderImageWithScale(pageIndex, dpi / 72.0, imageType);
  }

  ImageBuffer renderImageWithScale(int pageIndex, double scale,
      [ImageType imageType = ImageType.RGB,
      RenderDestination? destination]) {
    final PDPage page = document.getPage(pageIndex);
    final PDRectangle cropBox = page.cropBox ?? page.mediaBox ?? PDRectangle.letter;
    final widthPt = cropBox.width;
    final heightPt = cropBox.height;

    // PDFBOX-4306 avoid single blank pixel line on the right or on the bottom
    int widthPx = math.max(1, (widthPt * scale).floor());
    int heightPx = math.max(1, (heightPt * scale).floor());

    final rotationAngle = page.rotation;

    // Always render to ARGB to ensure clip masks and transparency (alpha/SMask)
    // are respected by the graphics backend, then composite onto white when
    // RGB output is requested.
    final useArgb = true;

    // Swap width and height for 90 or 270 degree rotation
    if (rotationAngle == 90 || rotationAngle == 270) {
      final tmp = widthPx;
      widthPx = heightPx;
      heightPx = tmp;
    }

    final buffer = ImageBuffer(widthPx, heightPx);
    final graphics = buffer.newGraphics2D();
    // Always start transparent; RGB output is composited onto white later.
    graphics.clear(Color(0, 0, 0, 0));

    // Apply transform similar to Java
    _transform(graphics, rotationAngle, cropBox, scale, scale);

    final actualDestination = destination ?? _defaultDestination;
    final params = PageDrawerParameters(
      this,
      page,
      _subsamplingAllowed,
      actualDestination,
      _renderingHints,
      _imageDownscalingOptimizationThreshold,
    );

    final drawer = createPageDrawer(params);
    drawer.drawPage(graphics, cropBox);

    // If we used ARGB for blend modes but user wanted RGB, composite on white
    if (useArgb && imageType == ImageType.RGB) {
      final newBuffer = ImageBuffer(widthPx, heightPx);
      final src = buffer.getBuffer();
      final dst = newBuffer.getBuffer();
      for (var i = 0; i < src.length; i += 4) {
        final a = src[i + 3];
        final invA = 255 - a;
        dst[i] = (src[i] + invA).clamp(0, 255);
        dst[i + 1] = (src[i + 1] + invA).clamp(0, 255);
        dst[i + 2] = (src[i + 2] + invA).clamp(0, 255);
        dst[i + 3] = 255;
      }
      return newBuffer;
    }

    return buffer;
  }

  /// Renders a page to an existing Graphics2D instance.
  ///
  /// This method can be used to render onto a larger canvas or to combine
  /// multiple pages.
  void renderPageToGraphics(int pageIndex, Graphics2D graphics,
      [double scaleX = 1.0, double? scaleY, RenderDestination? destination]) {
    scaleY ??= scaleX;
    final PDPage page = document.getPage(pageIndex);
    final PDRectangle cropBox = page.cropBox ?? page.mediaBox ?? PDRectangle.letter;

    _transform(graphics, page.rotation, cropBox, scaleX, scaleY);

    final actualDestination = destination ?? _defaultDestination;
    final params = PageDrawerParameters(
      this,
      page,
      _subsamplingAllowed,
      actualDestination,
      _renderingHints,
      _imageDownscalingOptimizationThreshold,
    );

    final drawer = createPageDrawer(params);
    drawer.drawPage(graphics, cropBox);
  }

  /// Applies scale and rotation transform to the graphics context.
  void _transform(Graphics2D graphics, int rotationAngle, PDRectangle cropBox,
      double scaleX, double scaleY) {
    final llx = cropBox.lowerLeftX;
    final lly = cropBox.lowerLeftY;
    final width = cropBox.width;
    final height = cropBox.height;

    if (rotationAngle == 0) {
      // Map PDF user space (origin bottom-left) to device space (origin top-left).
      graphics.setTransform(Affine(
        scaleX,
        0,
        0,
        -scaleY,
        -llx * scaleX,
        (height + lly) * scaleY,
      ));
      return;
    }

    // Rotation path: keep close to PDFBox sequencing.
    final radians = rotationAngle * math.pi / 180;
    double translateX = 0;
    double translateY = 0;
    switch (rotationAngle) {
      case 90:
        translateX = height;
        break;
      case 270:
        translateY = width;
        break;
      case 180:
        translateX = width;
        translateY = height;
        break;
      default:
        break;
    }

    var transform = Matrix();
    transform = transform.multiply(
      Matrix.getTranslateInstance(-llx, -lly),
    );
    transform = transform.multiply(
      Matrix.getTranslateInstance(translateX, translateY),
    );
    transform = transform.multiply(Matrix.getRotateInstance(radians, 0, 0));
    transform =
        transform.multiply(Matrix.getScaleInstance(1, -1)); // flip Y axis
    transform = transform.multiply(Matrix.getTranslateInstance(0, height));
    transform = transform.multiply(Matrix.getScaleInstance(scaleX, scaleY));

    graphics.setTransform(Affine(
      transform.scaleX,
      transform.shearY,
      transform.shearX,
      transform.scaleY,
      transform.translateX,
      transform.translateY,
    ));
  }

  /// Renders a page to PNG bytes.
  Uint8List renderImageToPngBytes(
    int pageIndex, {
    double scale = 1.0,
    ImageType imageType = ImageType.RGB,
  }) {
    final image = renderImageWithScale(pageIndex, scale, imageType);
    return PngEncoder.encode(image);
  }

  /// Renders a page and saves it as a PNG file.
  void renderImageToPngFile(
    int pageIndex,
    String filename, {
    double scale = 1.0,
    ImageType imageType = ImageType.RGB,
  }) {
    final image = renderImageWithScale(pageIndex, scale, imageType);
    PngEncoder.saveImage(image, filename);
  }

  /// Factory method which may be overridden to provide custom rendering.
  PageDrawer createPageDrawer(PageDrawerParameters parameters) {
    return PageDrawer(parameters);
  }
}

