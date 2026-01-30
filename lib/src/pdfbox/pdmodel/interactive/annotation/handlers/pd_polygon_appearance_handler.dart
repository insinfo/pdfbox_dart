import 'dart:math';

import '../../../common/pd_rectangle.dart';
import '../../../pd_appearance_content_stream.dart';
import '../../../pd_document.dart';
import '../pd_annotation.dart';
import '../pd_annotation_polygon.dart';
import '../pd_border_effect_dictionary.dart';
import 'annotation_border.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the polygon annotations appearance.
class PDPolygonAppearanceHandler extends PDAbstractAppearanceHandler {
  PDPolygonAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    final annot = getAnnotation();
    if (annot is! PDAnnotationPolygon) return;

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
    final interiorColor = annot.getInteriorColor();
    
    final hasStroke = color != null && color.components.isNotEmpty;
    final hasFill = interiorColor != null && interiorColor.components.isNotEmpty;
    
    if (!hasStroke && !hasFill) {
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
    
    // Expand rectangle for line width
    final padding = ab.width + 1;
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

      if (hasStroke) {
        cs.setStrokingColorPD(color);
      }
      if (hasFill) {
        cs.setNonStrokingColorPD(interiorColor);
      }
      
      if (ab.dashArray != null) {
        cs.setLineDashPattern(ab.dashArray!, 0);
      }
      cs.setLineWidth(ab.width);

      // Check for cloudy border effect
      final borderEffect = annot.getBorderEffect();
      if (borderEffect != null && 
          borderEffect.getStyle() == PDBorderEffectDictionary.STYLE_CLOUDY) {
        // TODO: Implement cloudy border
        // For now, draw regular polygon
        _drawPolygon(cs, vertices);
      } else {
        _drawPolygon(cs, vertices);
      }

      // Fill and/or stroke
      if (hasFill && hasStroke) {
        cs.closePath();
        cs.fillAndStroke();
      } else if (hasFill) {
        cs.closePath();
        cs.fill();
      } else if (hasStroke) {
        cs.closePath();
        cs.stroke();
      }
    } catch (ex) {
      // LOG.error(ex);
    } finally {
      cs?.close();
    }
  }

  void _drawPolygon(PDAppearanceContentStream cs, List<double> vertices) {
    final nPoints = vertices.length ~/ 2;
    if (nPoints < 2) return;
    
    // Move to first point
    cs.moveTo(vertices[0], vertices[1]);
    
    // Line to remaining points
    for (int i = 1; i < nPoints; i++) {
      cs.lineTo(vertices[i * 2], vertices[i * 2 + 1]);
    }
    
    // Close the polygon
    cs.closePath();
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
