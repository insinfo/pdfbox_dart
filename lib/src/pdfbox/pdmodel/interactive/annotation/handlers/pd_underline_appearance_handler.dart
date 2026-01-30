import 'dart:math';

import '../../../common/pd_rectangle.dart';
import '../../../pd_appearance_content_stream.dart';
import '../../../pd_document.dart';
import '../pd_annotation.dart';
import '../pd_annotation_underline.dart';
import 'annotation_border.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the underline annotations appearance.
class PDUnderlineAppearanceHandler extends PDAbstractAppearanceHandler {
  PDUnderlineAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    final annot = getAnnotation();
    if (annot is! PDAnnotationUnderline) return;
    
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

    // Adjust rectangle even if not empty, see PLPDF.com-MarkupAnnotations.pdf
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
    rect = PDRectangle(
      min(minX - ab.width / 2, rect.lowerLeftX),
      min(minY - ab.width / 2, rect.lowerLeftY),
      max(maxX + ab.width / 2, rect.upperRightX) -
          min(minX - ab.width / 2, rect.lowerLeftX),
      max(maxY + ab.width / 2, rect.upperRightY) -
          min(minY - ab.width / 2, rect.lowerLeftY),
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

      // spec is incorrect
      // https://stackoverflow.com/questions/9855814/pdf-spec-vs-acrobat-creation-quadpoints
      final nQuads = pathsArray.length ~/ 8;
      for (int i = 0; i < nQuads; ++i) {
        // Adobe doesn't use the lower coordinate for the line, it uses lower + delta / 7.
        // do the math for diagonal annotations with this weird old trick:
        // https://stackoverflow.com/questions/7740507/extend-a-line-segment-a-specific-distance
        final len0 = sqrt(pow(pathsArray[i * 8] - pathsArray[i * 8 + 4], 2) +
            pow(pathsArray[i * 8 + 1] - pathsArray[i * 8 + 5], 2));
        double x0 = pathsArray[i * 8 + 4];
        double y0 = pathsArray[i * 8 + 5];
        if (len0 != 0) {
          // only if both coordinates are not identical to avoid divide by zero
          x0 +=
              (pathsArray[i * 8] - pathsArray[i * 8 + 4]) / len0 * len0 / 7;
          y0 +=
              (pathsArray[i * 8 + 1] - pathsArray[i * 8 + 5]) / len0 * len0 / 7;
        }
        final len1 = sqrt(pow(pathsArray[i * 8 + 2] - pathsArray[i * 8 + 6], 2) +
            pow(pathsArray[i * 8 + 3] - pathsArray[i * 8 + 7], 2));
        double x1 = pathsArray[i * 8 + 6];
        double y1 = pathsArray[i * 8 + 7];
        if (len1 != 0) {
          // only if both coordinates are not identical to avoid divide by zero
          x1 +=
              (pathsArray[i * 8 + 2] - pathsArray[i * 8 + 6]) / len1 * len1 / 7;
          y1 +=
              (pathsArray[i * 8 + 3] - pathsArray[i * 8 + 7]) / len1 * len1 / 7;
        }
        cs.moveTo(x0, y0);
        cs.lineTo(x1, y1);
      }
      cs.stroke();
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
