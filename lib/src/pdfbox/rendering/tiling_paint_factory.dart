import 'dart:math' as math;

import 'package:dart_graphics/dart_graphics.dart';

import '../pdmodel/graphics/pattern/pd_tiling_pattern.dart';
import '../util/matrix.dart';
import 'tiling_paint.dart';

/// Port of PDFBox's `TilingPaintFactory`.
final class TilingPaintFactory {
  TilingPaintFactory();

  static void _noopDrawCell(
    PDTilingPattern pattern,
    Graphics2D graphics,
    Affine base,
  ) {}

  TilingPaint? create({
    required PDTilingPattern pattern,
    void Function(PDTilingPattern pattern, Graphics2D graphics, Affine base)
        drawCell = _noopDrawCell,
    required Affine base,
    required Matrix ctm,
  }) {
    final bbox = pattern.boundingBox;
    if (bbox == null) {
      return null;
    }

    final xStep = pattern.xStep;
    final yStep = pattern.yStep;
    if (xStep == 0 || yStep == 0) {
      return null;
    }

    // Device-space step sizes. Use distances so this works with flips and
    // simple rotations/shears.
    final combined = _combine(base, ctm);
    final p0 = combined.transformPoint(0, 0);
    final px = combined.transformPoint(xStep, 0);
    final py = combined.transformPoint(0, yStep);

    final xStepPx = math.max(
      1,
      math.sqrt(math.pow(px.x - p0.x, 2) + math.pow(px.y - p0.y, 2)).round(),
    );
    final yStepPx = math.max(
      1,
      math.sqrt(math.pow(py.x - p0.x, 2) + math.pow(py.y - p0.y, 2)).round(),
    );

    // Render one full pattern cell in pixel space (one step in each direction).
    final tileW = xStepPx;
    final tileH = yStepPx;

    final tile = ImageBuffer(tileW, tileH);
    final tileG = tile.newGraphics2D();
    tileG.clear(Color(0, 0, 0, 0));

    // Base transform for the tile: map pattern space (0..XStep,0..YStep) into
    // tile pixels, with Y flipped to match PDF coordinate system.
    final scaleX = tileW / xStep;
    final scaleY = tileH / yStep;

    tileG.setTransform(Affine(scaleX, 0, 0, -scaleY, 0, tileH.toDouble()));

    // Render the pattern cell content into the tile.
    final tileBase = Affine(scaleX, 0, 0, -scaleY, 0, tileH.toDouble());
    drawCell(pattern, tileG, tileBase);

    // Pattern origin in device pixels.
    final origin = combined.transformPoint(0, 0);

    return TilingPaint(
      tile: tile,
      xStepPx: xStepPx,
      yStepPx: yStepPx,
      originX: origin.x.round(),
      originY: origin.y.round(),
    );
  }

  Affine _combine(Affine base, Matrix ctm) {
    final ctmAffine = Affine(
      ctm.scaleX,
      ctm.shearY,
      ctm.shearX,
      ctm.scaleY,
      ctm.translateX,
      ctm.translateY,
    );
    final out = Affine(base.sx, base.shy, base.shx, base.sy, base.tx, base.ty);
    out.multiply(ctmAffine);
    return out;
  }
}

