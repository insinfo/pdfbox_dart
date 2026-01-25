import 'package:meta/meta.dart';

import '../pdmodel/pd_page.dart';
import 'pdf_renderer.dart';
import 'render_destination.dart';

/// Port of PDFBox's `PageDrawerParameters`.
///
/// This is a small data carrier that allows `PDFRenderer` and `PageDrawer` to
/// share implementation details while allowing custom subclasses.
@immutable
final class PageDrawerParameters {
  const PageDrawerParameters(
    this._renderer,
    this._page,
    this._subsamplingAllowed,
    this._destination,
    this._renderingHints,
    this._imageDownscalingOptimizationThreshold,
  );

  final PDFRenderer _renderer;
  final PDPage _page;
  final bool _subsamplingAllowed;
  final RenderDestination _destination;
  final Object? _renderingHints;
  final double _imageDownscalingOptimizationThreshold;

  PDPage getPage() => _page;

  PDFRenderer getRenderer() => _renderer;

  bool isSubsamplingAllowed() => _subsamplingAllowed;

  RenderDestination getDestination() => _destination;

  Object? getRenderingHints() => _renderingHints;

  double getImageDownscalingOptimizationThreshold() =>
      _imageDownscalingOptimizationThreshold;
}

