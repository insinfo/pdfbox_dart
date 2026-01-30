import 'dart:math';

import '../../../common/pd_rectangle.dart';
import '../../../pd_appearance_content_stream.dart';
import '../../../pd_document.dart';
import '../pd_annotation.dart';
import '../pd_annotation_highlight.dart';
import 'annotation_border.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the highlight annotations appearance.
///
/// TODO: Full implementation requires:
/// - PDExtendedGraphicsState setters: alphaSourceFlag, blendMode
/// - PDFormXObject constructor from PDStream (not COSStream)
/// - PDTransparencyGroupAttributes support
/// 
/// This is a simplified version that draws highlight as filled quadrilaterals
/// without transparency group and blend mode (which requires more infrastructure).
class PDHighlightAppearanceHandler extends PDAbstractAppearanceHandler {
  PDHighlightAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    final annot = getAnnotation();
    if (annot is! PDAnnotationHighlight) return;

    final pathsArray = annot.getQuadPoints();
    if (pathsArray == null || pathsArray.isEmpty) {
      return;
    }
    final color = getColor();
    if (color == null || color.components.isEmpty) {
      return;
    }
    PDRectangle? rect = annot.rectangle;
    if (rect == null) {
      return;
    }
    final ab = AnnotationBorder.getAnnotationBorder(annot, annot.borderStyle);

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

    // get the delta used for curves and use it for padding
    double maxDelta = 0;
    final nQuadsForDelta = pathsArray.length ~/ 8;
    for (int i = 0; i < nQuadsForDelta; ++i) {
      final delta = max(
          (pathsArray[i + 0] - pathsArray[i + 4]) / 4,
          (pathsArray[i + 1] - pathsArray[i + 5]) / 4);
      maxDelta = max(delta, maxDelta);
    }

    rect = PDRectangle(
      min(minX - ab.width / 2 - maxDelta, rect.lowerLeftX),
      min(minY - ab.width / 2 - maxDelta, rect.lowerLeftY),
      max(maxX + ab.width + maxDelta, rect.upperRightX) -
          min(minX - ab.width / 2 - maxDelta, rect.lowerLeftX),
      max(maxY + ab.width + maxDelta, rect.upperRightY) -
          min(minY - ab.width / 2 - maxDelta, rect.lowerLeftY),
    );
    annot.rect = rect.toCOSArray().toDoubleList();

    PDAppearanceContentStream? cs;
    try {
      cs = getNormalAppearanceAsContentStream();
      setOpacity(cs, annot.constantOpacity);
      cs.setNonStrokingColorPD(color);

      // Simplified rendering: draw filled quadrilaterals without transparency
      // TODO: Full implementation should use PDFormXObject with transparency group
      // and blend mode MULTIPLY as in the Java reference implementation
      int of = 0;
      while (of + 7 < pathsArray.length) {
        // quadpoints spec sequence is incorrect, correct one is (4,5 0,1 2,3 6,7)
        // https://stackoverflow.com/questions/9855814/pdf-spec-vs-acrobat-creation-quadpoints
        cs.moveTo(pathsArray[of + 4], pathsArray[of + 5]);
        cs.lineTo(pathsArray[of + 0], pathsArray[of + 1]);
        cs.lineTo(pathsArray[of + 2], pathsArray[of + 3]);
        cs.lineTo(pathsArray[of + 6], pathsArray[of + 7]);
        cs.closePath();
        cs.fill();
        of += 8;
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
