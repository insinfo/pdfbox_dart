import 'dart:math';

import '../../../common/pd_rectangle.dart';
import '../../../pd_appearance_content_stream.dart';
import '../../../pd_document.dart';
import '../pd_annotation.dart';
import '../pd_annotation_line.dart';
import '../pd_annotation_polyline.dart';
import 'annotation_border.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the polyline annotations appearance.
class PDPolylineAppearanceHandler extends PDAbstractAppearanceHandler {
  PDPolylineAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    final annot = getAnnotation();
    if (annot is! PDAnnotationPolyline) return;

    final vertices = annot.getVertices();
    if (vertices == null || vertices.length < 4) {
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

    // Calculate bounding box from vertices
    double minX = double.maxFinite;
    double minY = double.maxFinite;
    double maxX = -double.maxFinite;
    double maxY = -double.maxFinite;
    
    final nPoints = vertices.length ~/ 2;
    for (int i = 0; i < nPoints; i++) {
      final x = vertices[i * 2];
      final y = vertices[i * 2 + 1];
      minX = min(minX, x);
      minY = min(minY, y);
      maxX = max(maxX, x);
      maxY = max(maxY, y);
    }
    
    // Expand rectangle for line width and line endings
    final padding = ab.width * 10; // Extra space for line endings
    rect = PDRectangle(
      minX - padding,
      minY - padding,
      (maxX - minX) + padding * 2,
      (maxY - minY) + padding * 2,
    );
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

      // Draw polyline
      cs.moveTo(vertices[0], vertices[1]);
      for (int i = 1; i < nPoints; i++) {
        cs.lineTo(vertices[i * 2], vertices[i * 2 + 1]);
      }

      cs.stroke();

      // Draw line endings
      final startStyle = annot.getStartPointEndingStyle();
      final endStyle = annot.getEndPointEndingStyle();
      final interiorColor = annot.getInteriorColor();

      if (startStyle != PDAnnotationLine.leNone && nPoints >= 2) {
        // Calculate angle at start
        final dx = vertices[2] - vertices[0];
        final dy = vertices[3] - vertices[1];
        final angle = atan2(dy, dx);
        _drawLineEnding(cs, vertices[0], vertices[1], angle + pi, startStyle, 
            ab.width, interiorColor);
      }

      if (endStyle != PDAnnotationLine.leNone && nPoints >= 2) {
        // Calculate angle at end
        final lastIdx = (nPoints - 1) * 2;
        final prevIdx = (nPoints - 2) * 2;
        final dx = vertices[lastIdx] - vertices[prevIdx];
        final dy = vertices[lastIdx + 1] - vertices[prevIdx + 1];
        final angle = atan2(dy, dx);
        _drawLineEnding(cs, vertices[lastIdx], vertices[lastIdx + 1], angle, 
            endStyle, ab.width, interiorColor);
      }
    } catch (ex) {
      // LOG.error(ex);
    } finally {
      cs?.close();
    }
  }

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
      } else {
        cs.stroke();
      }
    } else if (style == PDAnnotationLine.leCircle) {
      _drawCircle(cs, x, y, arrowWidth, interiorColor);
    } else if (style == PDAnnotationLine.leSquare) {
      final size = arrowWidth * 2;
      cs.addRect(x - size / 2, y - size / 2, size, size);
      if (interiorColor != null) {
        cs.setNonStrokingColorPD(interiorColor);
        cs.fillAndStroke();
      } else {
        cs.stroke();
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
      } else {
        cs.stroke();
      }
    } else if (style == PDAnnotationLine.leButt) {
      final size = arrowWidth;
      final perpAngle = angle + pi / 2;
      cs.moveTo(x + size * cos(perpAngle), y + size * sin(perpAngle));
      cs.lineTo(x - size * cos(perpAngle), y - size * sin(perpAngle));
      cs.stroke();
    }

    cs.restoreGraphicsState();
  }

  void _drawCircle(PDAppearanceContentStream cs, double cx, double cy,
      double radius, dynamic interiorColor) {
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
    } else {
      cs.stroke();
    }
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
