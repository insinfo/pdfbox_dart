import 'dart:math';

import '../../../common/pd_rectangle.dart';
import '../../../pd_appearance_content_stream.dart';
import '../../../pd_document.dart';
import '../pd_annotation.dart';
import '../pd_annotation_line.dart';
import 'annotation_border.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the line annotations appearance.
class PDLineAppearanceHandler extends PDAbstractAppearanceHandler {
  PDLineAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    final annot = getAnnotation();
    if (annot is! PDAnnotationLine) return;

    final line = annot.getLine();
    if (line == null || line.length < 4) {
      return;
    }

    PDRectangle? rect = annot.rectangle;
    if (rect == null) {
      return;
    }

    final ab = AnnotationBorder.getAnnotationBorder(annot, annot.borderStyle);
    final color = getColor();
    if (color == null || color.components.isEmpty) {
      return;
    }

    // Line coordinates
    final x1 = line[0];
    final y1 = line[1];
    final x2 = line[2];
    final y2 = line[3];

    // Leader line lengths
    final ll = annot.getLeaderLineLength();
    final lle = annot.getLeaderLineExtensionLength();
    final llo = annot.getLeaderLineOffsetLength();

    // Calculate line angle
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lineLength = sqrt(dx * dx + dy * dy);
    double angle = 0;
    if (lineLength > 0) {
      angle = atan2(dy, dx);
    }

    // Perpendicular unit vector
    final perpX = -sin(angle);
    final perpY = cos(angle);

    // Adjust rectangle to include leader lines
    double minX = min(x1, x2);
    double minY = min(y1, y2);
    double maxX = max(x1, x2);
    double maxY = max(y1, y2);

    // Expand for leader lines if present
    if (ll != 0) {
      final extent = ll.abs() + lle;
      minX -= extent + ab.width;
      minY -= extent + ab.width;
      maxX += extent + ab.width;
      maxY += extent + ab.width;
    } else {
      minX -= ab.width * 2;
      minY -= ab.width * 2;
      maxX += ab.width * 2;
      maxY += ab.width * 2;
    }

    rect = PDRectangle(minX, minY, maxX - minX, maxY - minY);
    annot.rect = rect.toCOSArray().toDoubleList();

    PDAppearanceContentStream? cs;
    try {
      cs = getNormalAppearanceAsContentStream();
      setOpacity(cs, annot.constantOpacity);

      cs.setStrokingColorPD(color);
      if (ab.dashArray != null) {
        cs.setLineDashPattern(ab.dashArray!, 0);
      }
      cs.setLineWidth(ab.width);

      // Start and end points (may be adjusted for leader lines)
      double startX = x1;
      double startY = y1;
      double endX = x2;
      double endY = y2;

      // Draw leader lines if present
      if (ll != 0) {
        final sign = ll > 0 ? 1.0 : -1.0;
        final llAbs = ll.abs();

        // Leader line at start point
        if (llo > 0) {
          cs.moveTo(x1 + perpX * llo * sign, y1 + perpY * llo * sign);
        } else {
          cs.moveTo(x1, y1);
        }
        cs.lineTo(
            x1 + perpX * (llAbs + lle) * sign, y1 + perpY * (llAbs + lle) * sign);

        // Leader line at end point
        if (llo > 0) {
          cs.moveTo(x2 + perpX * llo * sign, y2 + perpY * llo * sign);
        } else {
          cs.moveTo(x2, y2);
        }
        cs.lineTo(
            x2 + perpX * (llAbs + lle) * sign, y2 + perpY * (llAbs + lle) * sign);

        // Adjust the main line to start/end at leader line positions
        startX = x1 + perpX * llAbs * sign;
        startY = y1 + perpY * llAbs * sign;
        endX = x2 + perpX * llAbs * sign;
        endY = y2 + perpY * llAbs * sign;
      }

      // Draw main line
      cs.moveTo(startX, startY);
      cs.lineTo(endX, endY);

      // Draw line ending styles
      final startStyle = annot.getStartPointEndingStyle();
      final endStyle = annot.getEndPointEndingStyle();

      _drawLineEnding(cs, startX, startY, angle + pi, startStyle, ab.width,
          annot.getInteriorColor());
      _drawLineEnding(
          cs, endX, endY, angle, endStyle, ab.width, annot.getInteriorColor());

      cs.stroke();

      // Draw caption if present
      if (annot.hasCaption()) {
        _drawCaption(cs, annot, startX, startY, endX, endY);
      }
    } catch (ex) {
      // LOG.error(ex);
    } finally {
      cs?.close();
    }
  }

  /// Draws a line ending style at the given position.
  void _drawLineEnding(PDAppearanceContentStream cs, double x, double y,
      double angle, String style, double lineWidth, dynamic interiorColor) {
    if (style == PDAnnotationLine.leNone) {
      return;
    }

    final arrowLength = lineWidth * 9;
    final arrowWidth = lineWidth * 3;

    cs.saveGraphicsState();

    if (style == PDAnnotationLine.leOpenArrow ||
        style == PDAnnotationLine.leClosedArrow) {
      final cosA = cos(angle);
      final sinA = sin(angle);

      // Arrow tip is at (x, y)
      final x1 = x - arrowLength * cosA + arrowWidth * sinA;
      final y1 = y - arrowLength * sinA - arrowWidth * cosA;
      final x2 = x - arrowLength * cosA - arrowWidth * sinA;
      final y2 = y - arrowLength * sinA + arrowWidth * cosA;

      cs.moveTo(x1, y1);
      cs.lineTo(x, y);
      cs.lineTo(x2, y2);

      if (style == PDAnnotationLine.leClosedArrow) {
        cs.closePath();
        if (interiorColor != null) {
          cs.setNonStrokingColorPD(interiorColor);
          cs.fillAndStroke();
        } else {
          cs.stroke();
        }
      }
    } else if (style == PDAnnotationLine.leROpenArrow ||
        style == PDAnnotationLine.leRClosedArrow) {
      // Reversed arrows - point away from line
      final cosA = cos(angle + pi);
      final sinA = sin(angle + pi);

      final x1 = x - arrowLength * cosA + arrowWidth * sinA;
      final y1 = y - arrowLength * sinA - arrowWidth * cosA;
      final x2 = x - arrowLength * cosA - arrowWidth * sinA;
      final y2 = y - arrowLength * sinA + arrowWidth * cosA;

      cs.moveTo(x1, y1);
      cs.lineTo(x, y);
      cs.lineTo(x2, y2);

      if (style == PDAnnotationLine.leRClosedArrow) {
        cs.closePath();
        if (interiorColor != null) {
          cs.setNonStrokingColorPD(interiorColor);
          cs.fillAndStroke();
        } else {
          cs.stroke();
        }
      }
    } else if (style == PDAnnotationLine.leCircle) {
      final radius = arrowWidth;
      _drawCircle(cs, x, y, radius, interiorColor);
    } else if (style == PDAnnotationLine.leSquare) {
      final size = arrowWidth * 2;
      cs.addRect(x - size / 2, y - size / 2, size, size);
      if (interiorColor != null) {
        cs.setNonStrokingColorPD(interiorColor);
        cs.fillAndStroke();
      }
    } else if (style == PDAnnotationLine.leDiamond) {
      final size = arrowWidth;
      cs.moveTo(x, y - size);
      cs.lineTo(x + size, y);
      cs.lineTo(x, y + size);
      cs.lineTo(x - size, y);
      cs.closePath();
      if (interiorColor != null) {
        cs.setNonStrokingColorPD(interiorColor);
        cs.fillAndStroke();
      }
    } else if (style == PDAnnotationLine.leButt) {
      // Butt - perpendicular line
      final size = arrowWidth;
      final perpAngle = angle + pi / 2;
      cs.moveTo(x + size * cos(perpAngle), y + size * sin(perpAngle));
      cs.lineTo(x - size * cos(perpAngle), y - size * sin(perpAngle));
    } else if (style == PDAnnotationLine.leSlash) {
      // Slash - diagonal line
      final size = arrowWidth;
      final slashAngle = angle + pi / 4;
      cs.moveTo(x + size * cos(slashAngle), y + size * sin(slashAngle));
      cs.lineTo(x - size * cos(slashAngle), y - size * sin(slashAngle));
    }

    cs.restoreGraphicsState();
  }

  void _drawCircle(PDAppearanceContentStream cs, double cx, double cy,
      double radius, dynamic interiorColor) {
    // Circle using Bezier curves (magic number for Bezier approximation)
    const magic = 0.551915024494;
    final m = radius * magic;

    cs.moveTo(cx + radius, cy);
    cs.curveTo(cx + radius, cy + m, cx + m, cy + radius, cx, cy + radius);
    cs.curveTo(cx - m, cy + radius, cx - radius, cy + m, cx - radius, cy);
    cs.curveTo(cx - radius, cy - m, cx - m, cy - radius, cx, cy - radius);
    cs.curveTo(cx + m, cy - radius, cx + radius, cy - m, cx + radius, cy);
    cs.closePath();

    if (interiorColor != null) {
      cs.setNonStrokingColorPD(interiorColor);
      cs.fillAndStroke();
    }
  }

  void _drawCaption(PDAppearanceContentStream cs, PDAnnotationLine annot,
      double x1, double y1, double x2, double y2) {
    final contents = annot.contents;
    if (contents == null || contents.isEmpty) {
      return;
    }

    // TODO: Full caption implementation requires font support
    // For now, captions are not rendered. When font infrastructure is ready,
    // use getDefaultFont() and render text at the appropriate position.
    //
    // The caption should be positioned based on:
    // - annot.getCaptionPositioning() - 'Inline' or 'Top'
    // - annot.getCaptionHorizontalOffset()
    // - annot.getCaptionVerticalOffset()
  }

  @override
  void generateRolloverAppearance() {
    // No rollover appearance generated
  }

  @override
  void generateDownAppearance() {
    // No down appearance generated
  }
}
