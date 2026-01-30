import 'dart:math';

import '../../../common/pd_rectangle.dart';
import '../../../pd_appearance_content_stream.dart';
import '../../../pd_document.dart';
import '../pd_annotation.dart';
import '../pd_annotation_squiggly.dart';
import 'annotation_border.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the squiggly annotations appearance.
///
/// The squiggly annotation draws a wavy underline pattern using
/// a series of bezier curves to create the squiggle effect.
class PDSquigglyAppearanceHandler extends PDAbstractAppearanceHandler {
  PDSquigglyAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    final annot = getAnnotation();
    if (annot is! PDAnnotationSquiggly) return;

    PDRectangle? rect = annot.rectangle;
    if (rect == null) {
      return;
    }
    final pathsArray = annot.getQuadPoints();
    if (pathsArray == null || pathsArray.isEmpty) {
      return;
    }
    final ab = AnnotationBorder.getAnnotationBorder(annot, annot.borderStyle);
    final color = getColor();
    if (color == null || color.components.isEmpty) {
      return;
    }
    if (ab.width == 0) {
      // value found in adobe reader
      ab.width = 1.5;
    }

    // Adjust rectangle
    double minX = double.maxFinite;
    double minY = double.maxFinite;
    double maxX = -double.maxFinite;
    double maxY = -double.maxFinite;
    final nPoints = pathsArray.length ~/ 2;
    for (int i = 0; i < nPoints; ++i) {
      final x = pathsArray[i * 2];
      final y = pathsArray[i * 2 + 1];
      minX = min(minX, x);
      minY = min(minY, y);
      maxX = max(maxX, x);
      maxY = max(maxY, y);
    }

    // A squiggle needs a bit more vertical space than a simple line
    final squiggleHeight = ab.width * 2;
    rect = PDRectangle(
      min(minX - ab.width / 2, rect.lowerLeftX),
      min(minY - ab.width / 2 - squiggleHeight, rect.lowerLeftY),
      max(maxX + ab.width / 2, rect.upperRightX) -
          min(minX - ab.width / 2, rect.lowerLeftX),
      max(maxY + ab.width / 2 + squiggleHeight, rect.upperRightY) -
          min(minY - ab.width / 2 - squiggleHeight, rect.lowerLeftY),
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

      // Draw squiggly lines for each quad
      final nQuads = pathsArray.length ~/ 8;
      for (int i = 0; i < nQuads; ++i) {
        // QuadPoints order is: upper-left, upper-right, lower-left, lower-right
        // But PDF spec is incorrect, Adobe uses: 4,5 0,1 2,3 6,7 order
        // We need the lower line for underline effect
        final x0 = pathsArray[i * 8 + 4];
        final y0 = pathsArray[i * 8 + 5];
        final x1 = pathsArray[i * 8 + 6];
        final y1 = pathsArray[i * 8 + 7];

        // Draw squiggle from (x0, y0) to (x1, y1)
        _drawSquiggleLine(cs, x0, y0, x1, y1, ab.width);
      }
      cs.stroke();
    } catch (ex) {
      // LOG.error(ex);
    } finally {
      cs?.close();
    }
  }

  /// Draws a squiggly line from start to end using bezier curves.
  void _drawSquiggleLine(PDAppearanceContentStream cs, double x0, double y0,
      double x1, double y1, double lineWidth) {
    // Calculate line length and direction
    final dx = x1 - x0;
    final dy = y1 - y0;
    final length = sqrt(dx * dx + dy * dy);
    
    if (length < 0.001) return;
    
    // Unit vector along the line
    final ux = dx / length;
    final uy = dy / length;
    
    // Perpendicular unit vector
    final px = -uy;
    final py = ux;
    
    // Squiggle parameters
    final amplitude = lineWidth * 1.5; // Height of squiggle waves
    final wavelength = lineWidth * 4; // Distance between peaks
    final numWaves = (length / wavelength).floor();
    final actualWavelength = numWaves > 0 ? length / numWaves : length;
    
    // Start point
    cs.moveTo(x0, y0);
    
    if (numWaves < 1) {
      // If too short for a wave, just draw a line
      cs.lineTo(x1, y1);
      return;
    }
    
    // Draw waves using quadratic bezier approximation
    double currentX = x0;
    double currentY = y0;
    
    for (int w = 0; w < numWaves; w++) {
      // Alternate the wave direction
      final sign = (w % 2 == 0) ? 1.0 : -1.0;
      
      // Control point 1 (quarter wavelength)
      final cp1x = currentX + ux * (actualWavelength * 0.25) + px * amplitude * sign * 0.5;
      final cp1y = currentY + uy * (actualWavelength * 0.25) + py * amplitude * sign * 0.5;
      
      // Control point 2 (half wavelength, peak of wave)
      final cp2x = currentX + ux * (actualWavelength * 0.5) + px * amplitude * sign;
      final cp2y = currentY + uy * (actualWavelength * 0.5) + py * amplitude * sign;
      
      // End point of this segment (3/4 wavelength)
      final midX = currentX + ux * (actualWavelength * 0.75) + px * amplitude * sign * 0.5;
      final midY = currentY + uy * (actualWavelength * 0.75) + py * amplitude * sign * 0.5;
      
      // End point (full wavelength)
      final endX = currentX + ux * actualWavelength;
      final endY = currentY + uy * actualWavelength;
      
      // Draw the curve using curveTo
      cs.curveTo(cp1x, cp1y, cp2x, cp2y, midX, midY);
      cs.curveTo(
        midX + ux * (actualWavelength * 0.125),
        midY + uy * (actualWavelength * 0.125),
        endX - ux * (actualWavelength * 0.125),
        endY - uy * (actualWavelength * 0.125),
        endX,
        endY,
      );
      
      currentX = endX;
      currentY = endY;
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
