import 'package:dart_graphics/dart_graphics.dart';

/// Port of PDFBox's `TilingPaint` concept.
///
/// Note: In the Java version this implements `Paint`. In this Dart port we keep a
/// minimal helper that can stamp a pre-rendered tile into a target buffer.
final class TilingPaint {
  TilingPaint({
    required this.tile,
    required this.xStepPx,
    required this.yStepPx,
    required this.originX,
    required this.originY,
  });

  final ImageBuffer tile;
  final int xStepPx;
  final int yStepPx;

  /// Pattern origin in device pixels.
  final int originX;
  final int originY;

  void paintInto(ImageBuffer target, int dx, int dy) {
    final w = target.width;
    final h = target.height;

    final tileW = tile.width;
    final tileH = tile.height;
    if (tileW <= 0 || tileH <= 0) {
      return;
    }

    final g = target.newGraphics2D();
    g.setTransform(Affine.identity());

    final startX = ((dx - originX) ~/ xStepPx) * xStepPx + originX;
    final startY = ((dy - originY) ~/ yStepPx) * yStepPx + originY;

    for (var y = startY; y < dy + h; y += yStepPx) {
      for (var x = startX; x < dx + w; x += xStepPx) {
        g.drawImage(
          tile,
          (x - dx).toDouble(),
          (y - dy).toDouble(),
          tileW.toDouble(),
          tileH.toDouble(),
        );
      }
    }
  }
}
