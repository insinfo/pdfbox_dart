import '../../../../cos/cos_number.dart';

import '../../../pd_document.dart';
import '../pd_annotation.dart';
import '../pd_annotation_markup.dart';
import '../pd_annotation_square.dart';
import '../pd_border_effect_dictionary.dart';

import 'cloudy_border.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the square annotations appearance.
class PDSquareAppearanceHandler extends PDAbstractAppearanceHandler {
  PDSquareAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    final lineWidth = getLineWidth();
    final annotation = getAnnotation() as PDAnnotationSquare;

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
          final rect = getRectangle();
          if (rect != null) {
              final cloudyBorder = CloudyBorder(contentStream, borderEffect.getIntensity(), lineWidth, rect);
              cloudyBorder.createCloudyRectangle(annotation.getRectDifference());
              annotation.setRectangle(cloudyBorder.getRectangle());
              annotation.setRectDifference(cloudyBorder.getRectDifference());
              final pdAppearanceStream = annotation.getNormalAppearanceStream();
              if (pdAppearanceStream != null) {
                  pdAppearanceStream.boundingBox = cloudyBorder.getBBox();
              }
          }
      } else {
        final borderBox = handleBorderBox(annotation, lineWidth);
        if (borderBox != null) {
          contentStream.addRect(borderBox.lowerLeftX, borderBox.lowerLeftY,
              borderBox.width, borderBox.height);
        }
      }

      contentStream.drawShape(lineWidth, hasStroke, hasBackground);
    } finally {
      contentStream.close();
    }
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
    if (borderCharacteristics.length >= 3) {
      final base = borderCharacteristics.getObject(2);
      if (base is COSNumber) {
        return base.doubleValue;
      }
    }

    return 1.0;
  }
}
