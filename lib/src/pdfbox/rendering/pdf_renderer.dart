import 'package:dart_graphics/dart_graphics.dart';

import 'dart:math' as math;

import '../pdmodel/common/pd_rectangle.dart';
import '../pdmodel/pd_document.dart';
import '../pdmodel/pd_page.dart';
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
      [ImageType imageType = ImageType.RGB]) {
    final PDPage page = document.getPage(pageIndex);
    final PDRectangle box = page.cropBox ?? page.mediaBox ?? PDRectangle.letter;
    final widthPx = math.max(1, (box.width * scale).ceil());
    final heightPx = math.max(1, (box.height * scale).ceil());

    final buffer = ImageBuffer(widthPx, heightPx);
    final graphics = buffer.newGraphics2D();
    graphics.clear(
      imageType == ImageType.ARGB
          ? Color(0, 0, 0, 0)
          : Color(255, 255, 255, 255),
    );

    // Base transform maps PDF coordinates into image pixels.
    // x' = (x - llx) * scale
    // y' = (ury - y) * scale
    final llx = box.lowerLeftX;
    final ury = box.lowerLeftY + box.height;
    graphics.setTransform(
      Affine(scale, 0, 0, -scale, -llx * scale, ury * scale),
    );

    final destination = _defaultDestination;
    final params = PageDrawerParameters(
      this,
      page,
      _subsamplingAllowed,
      destination,
      _renderingHints,
      _imageDownscalingOptimizationThreshold,
    );

    final drawer = createPageDrawer(params);
    drawer.drawPage(graphics, box);
    return buffer;
  }

  /// Factory method which may be overridden to provide custom rendering.
  PageDrawer createPageDrawer(PageDrawerParameters parameters) {
    return PageDrawer(parameters);
  }
}
