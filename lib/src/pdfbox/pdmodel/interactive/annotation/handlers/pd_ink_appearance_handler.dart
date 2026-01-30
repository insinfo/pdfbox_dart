import 'dart:math';

import '../../../common/pd_rectangle.dart';
import '../../../pd_appearance_content_stream.dart';
import '../../../pd_document.dart';
import '../pd_annotation.dart';
import '../pd_annotation_ink.dart';
import 'annotation_border.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the ink annotations appearance.
class PDInkAppearanceHandler extends PDAbstractAppearanceHandler {
  PDInkAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    final annot = getAnnotation();
    if (annot is! PDAnnotationInk) return;
    
    final color = getColor();
    if (color == null || color.components.isEmpty) {
      return;
    }
    // PDF spec does not mention /Border for ink annotations, but it is used if /BS is not available
    final ab = AnnotationBorder.getAnnotationBorder(annot, annot.borderStyle);
    if (ab.width == 0) {
      return;
    }

    // Adjust rectangle even if not empty
    //TODO in a class structure this should be overridable
    double minX = double.maxFinite;
    double minY = double.maxFinite;
    double maxX = -double.maxFinite;
    double maxY = -double.maxFinite;
    for (final pathArray in annot.getInkList()) {
      final nPoints = pathArray.length ~/ 2;
      for (int i = 0; i < nPoints; ++i) {
        final x = pathArray[i * 2];
        final y = pathArray[i * 2 + 1];
        minX = min(minX, x);
        minY = min(minY, y);
        maxX = max(maxX, x);
        maxY = max(maxY, y);
      }
    }
    PDRectangle? rect = annot.rectangle;
    if (rect == null) {
      return;
    }
    rect = PDRectangle(
      min(minX - ab.width * 2, rect.lowerLeftX),
      min(minY - ab.width * 2, rect.lowerLeftY),
      max(maxX + ab.width * 2, rect.upperRightX) -
          min(minX - ab.width * 2, rect.lowerLeftX),
      max(maxY + ab.width * 2, rect.upperRightY) -
          min(minY - ab.width * 2, rect.lowerLeftY),
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

      for (final pathArray in annot.getInkList()) {
        final nPoints = pathArray.length ~/ 2;

        // "When drawn, the points shall be connected by straight lines or curves
        // in an implementation-dependent way" - we do lines.
        for (int i = 0; i < nPoints; ++i) {
          final x = pathArray[i * 2];
          final y = pathArray[i * 2 + 1];

          if (i == 0) {
            cs.moveTo(x, y);
          } else {
            cs.lineTo(x, y);
          }
        }
        cs.stroke();
      }
    } catch (ex) {
      // LOG.error(ex);
    } finally {
      cs?.close();
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
