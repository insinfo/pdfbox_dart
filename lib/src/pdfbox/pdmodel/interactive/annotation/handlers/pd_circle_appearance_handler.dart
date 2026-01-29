import '../../../../cos/cos_number.dart';
import '../../../pd_document.dart';
import '../pd_annotation.dart';
import '../pd_annotation_markup.dart';
import '../pd_annotation_circle.dart';
import '../pd_border_effect_dictionary.dart';
import '../../../common/pd_rectangle.dart';

import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the circle annotations appearance.
class PDCircleAppearanceHandler extends PDAbstractAppearanceHandler {
  PDCircleAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    final lineWidth = getLineWidth();
    final annotation = getAnnotation();
    if (annotation is! PDAnnotationCircle) {
        return;
    }

    final contentStream = getNormalAppearanceAsContentStream();
    try {
      final hasStroke = contentStream.setStrokingColorOnDemand(getColor());
      final hasBackground =
          contentStream.setNonStrokingColorOnDemand(annotation.getInteriorColor());

      setOpacity(contentStream, annotation.constantOpacity);

      contentStream.setBorderLine(
          lineWidth, annotation.borderStyle, annotation.border);

      final borderEffect = annotation.getBorderEffect();
      
      if (borderEffect != null &&
          borderEffect.getStyle() == PDBorderEffectDictionary.STYLE_CLOUDY) {
          // TODO: Implement CloudyBorder
           // Fallback
           // We need to implement handleBorderBox for Circle too or reuse logic
           // The Java method signature was handleBorderBox(PDAnnotationSquareCircle, float)
           // In Dart PDAnnotationCircle extends PDAnnotationSquareCircle.
           
           final borderBox = handleBorderBox(annotation, lineWidth);
           if (borderBox != null) {
              _drawCircle(contentStream, borderBox);
           }
      } else {
        final borderBox = handleBorderBox(annotation, lineWidth);
        if (borderBox != null) {
           _drawCircle(contentStream, borderBox);
        }
      }

      contentStream.drawShape(lineWidth, hasStroke, hasBackground);
    } finally {
      contentStream.close();
    }
  }
  
  void _drawCircle(
      dynamic contentStream, PDRectangle borderBox) {
        // dynamic contentStream to avoid circular dep or import issues if any, but better use type
        // Actually imports are fine.
        
        // lower left corner
        final x0 = borderBox.lowerLeftX;
        final y0 = borderBox.lowerLeftY;
        // upper right corner
        final x1 = borderBox.upperRightX;
        final y1 = borderBox.upperRightY;
        // mid points
        final xm = x0 + borderBox.width / 2;
        final ym = y0 + borderBox.height / 2;
        // see http://spencermortensen.com/articles/bezier-circle/
        // the below number was calculated from sampling content streams
        // generated using Adobe Reader
        final magic = 0.55555417;
        // control point offsets
        final vOffset = borderBox.height / 2 * magic;
        final hOffset = borderBox.width / 2 * magic;

        contentStream.moveTo(xm, y1);
        contentStream.curveTo((xm + hOffset), y1, x1, (ym + vOffset), x1, ym);
        contentStream.curveTo(x1, (ym - vOffset), (xm + hOffset), y0, xm, y0);
        contentStream.curveTo((xm - hOffset), y0, x0, (ym - vOffset), x0, ym);
        contentStream.curveTo(x0, (ym + vOffset), (xm - hOffset), y1, xm, y1);
        contentStream.closePath();
  }

  @override
  void generateRolloverAppearance() {
    // TODO to be implemented
  }

  @override
  void generateDownAppearance() {
    // TODO to be implemented
  }

  @override
  void generateAppearanceStreams() {
      generateNormalAppearance();
      generateRolloverAppearance();
      generateDownAppearance();
  }

  /// Get the line width of the border.
  double getLineWidth() {
    final annotation = getAnnotation();
    if (annotation is! PDAnnotationMarkup) {
        return 1.0;
    }
    
    final bs = annotation.borderStyle;
    if (bs != null) {
      return bs.width;
    }

    final borderCharacteristics = annotation.border;
    if (borderCharacteristics != null && borderCharacteristics.length >= 3) {
      final base = borderCharacteristics.getObject(2);
      if (base is COSNumber) {
        return base.doubleValue;
      }
    }

    return 1.0;
  }
  
    // Overriding handleBorderBox from AbstractAppearanceHandler to accept Circle
  // Actually AbstractAppearanceHandler had: PDRectangle? handleBorderBox(PDAnnotationSquare annotation, double lineWidth)
  // I need to change AbstractAppearanceHandler to accept PDAnnotationSquareCircle.
  // But for now I'll cast inside AbstractAppearanceHandler if possible, or override here.
  // Since PDAnnotationSquare and PDAnnotationCircle both inherit from PDAnnotationSquareCircle,
  // I should update PDAbstractAppearanceHandler to use the base class.
}
