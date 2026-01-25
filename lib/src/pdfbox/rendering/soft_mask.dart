
import 'package:dart_graphics/dart_graphics.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/function/pdf_function.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/function/pdf_function_identity.dart';


/// A Paint-like helper which applies a soft mask to an underlying buffer.
///
/// Port of PDFBox's `SoftMask` class (which implements `java.awt.Paint`).
/// Since `dart_graphics` does not use AWT PaintContexts, this class provides
/// static helpers and logic to apply the soft mask to an [ImageBuffer].
class SoftMask {

  final ImageBuffer mask;
  final RectangleInt? bboxDevice;
  final PDFunction? transferFunction;
  int _bc = 0;

  /// Creates a new soft mask.
  ///
  /// [mask] is the evaluated soft mask (rasterized).
  /// [bboxDevice] is the bounding box of the soft mask in device space.
  /// [backdropGray] is the gray value (0-255) to be used outside the transparency
  /// group's bounding box; if null, black (0) will be used.
  /// [transferFunction] is the optional transfer function.
  SoftMask(
    this.mask, {
    this.bboxDevice,
    int? backdropGray,
    this.transferFunction,
  }) {
    if (backdropGray != null) {
      _bc = backdropGray.clamp(0, 255);
    }
  }

  bool get isIdentityTransfer =>
      transferFunction == null ||
      transferFunction is PDFunctionIdentity;

  /// Applies the soft mask to the [layer] buffer.
  ///
  /// [layer] is the target buffer to modulate.
  /// [dx], [dy] are the offsets in the [layer] where the drawing occurred relative to [mask].
  /// [luminosity] determines if the mask alpha is derived from luminosity or alpha channel.
  void apply(
    ImageBuffer layer,
    int dx,
    int dy, {
    required bool luminosity,
  }) {
    final layerBytes = layer.getBuffer();
    final maskBytes = mask.getBuffer();

    final w = layer.width;
    final h = layer.height;
    final fullW = mask.width;

    List<double?>? transferMap;
    final tf = transferFunction;
    if (tf != null && !isIdentityTransfer) {
      transferMap = List<double?>.filled(256, null);
    }

    final bbox = bboxDevice;
    final hasBBox = bbox != null;
    final bboxLeft =
        hasBBox ? (bbox.left < bbox.right ? bbox.left : bbox.right) : 0;
    final bboxRight =
        hasBBox ? (bbox.right > bbox.left ? bbox.right : bbox.left) : 0;
    final bboxTop =
        hasBBox ? (bbox.top < bbox.bottom ? bbox.top : bbox.bottom) : 0;
    final bboxBottom =
        hasBBox ? (bbox.bottom > bbox.top ? bbox.bottom : bbox.top) : 0;
    final bc = _bc;

    for (var y = 0; y < h; y++) {
      final maskRow = (dy + y) * fullW;
      final layerRow = y * w;
      for (var x = 0; x < w; x++) {
        final li = (layerRow + x) * 4;
        final px = dx + x;
        final py = dy + y;

        final insideBBox = !hasBBox
            ? true
            : (px >= bboxLeft &&
                px < bboxRight &&
                py >= bboxTop &&
                py < bboxBottom);

        int g; // gray value from mask
        if (!insideBBox) {
          g = bc;
        } else {
          // Check bounds against mask dimensions just in case
          if (px >= 0 && px < mask.width && py >= 0 && py < mask.height) {
            final mi = (maskRow + px) * 4;
            if (luminosity) {
              final r = maskBytes[mi];
              final gg = maskBytes[mi + 1];
              final b = maskBytes[mi + 2];
              // 0.299R + 0.587G + 0.114B
              g = ((299 * r + 587 * gg + 114 * b) ~/ 1000).clamp(0, 255);
            } else {
              g = maskBytes[mi + 3];
            }
          } else {
             g = bc;
          }
        }

        // Apply transfer function
        double factor;
        if (tf != null && transferMap != null && insideBBox) {
          final cached = transferMap[g];
          if (cached != null) {
            factor = cached;
          } else {
            try {
              // PDFBox Logic: input is 0..1
              final val = tf.eval(<double>[g / 255.0]);
              factor = val[0].clamp(0.0, 1.0);
              transferMap[g] = factor;
            } catch (_) {
              // PDFBox: treat as outside if fails
              factor = (bc / 255.0).clamp(0.0, 1.0);
            }
          }
        } else {
          factor = (g / 255.0).clamp(0.0, 1.0);
        }

        if (factor >= 0.999999) {
          // Keep alpha as is
          continue;
        }
        if (factor <= 0.000001) {
          // Fully transparent
          layerBytes[li] = 0;
          layerBytes[li + 1] = 0;
          layerBytes[li + 2] = 0;
          layerBytes[li + 3] = 0;
          continue;
        }

        final a = layerBytes[li + 3];
        final mf = (factor * 255.0).round().clamp(0, 255);
        layerBytes[li] = (layerBytes[li] * mf) ~/ 255;
        layerBytes[li + 1] = (layerBytes[li + 1] * mf) ~/ 255;
        layerBytes[li + 2] = (layerBytes[li + 2] * mf) ~/ 255;
        layerBytes[li + 3] = (a * mf) ~/ 255;
      }
    }
  }
}

/// Helper rect for integer bounds.


