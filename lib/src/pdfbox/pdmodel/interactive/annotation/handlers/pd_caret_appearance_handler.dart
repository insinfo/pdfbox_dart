import 'dart:math';

import '../../../../cos/cos_name.dart';
import '../../../common/pd_rectangle.dart';
import '../../../pd_appearance_content_stream.dart';
import '../../../pd_document.dart';
import '../pd_annotation.dart';
import '../pd_annotation_caret.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the caret annotations appearance.
class PDCaretAppearanceHandler extends PDAbstractAppearanceHandler {
  PDCaretAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    final annot = getAnnotation();
    if (annot is! PDAnnotationCaret) return;
    
    PDAppearanceContentStream? contentStream;
    try {
      contentStream = getNormalAppearanceAsContentStream();
      final color = getColor();
      if (color != null) {
        contentStream.setStrokingColorPD(color);
        contentStream.setNonStrokingColorPD(color);
      }

      setOpacity(contentStream, annot.constantOpacity);

      final rect = getRectangle();
      if (rect == null) return;

      final rectWidth = rect.width;
      final rectHeight = rect.height;
      PDRectangle bbox = PDRectangle(0, 0, rectWidth, rectHeight);
      final pdAppearanceStream = annot.getNormalAppearanceStream();

      if (pdAppearanceStream != null &&
          !annot.dictionary.containsKey(COSName.rd)) {
        // Adobe creates the /RD entry with a number that is decided
        // by dividing the height by 10, with a maximum result of 5.
        final rd = min(rectHeight / 10, 5.0);
        annot.setRectDifferences(rd);
        bbox = PDRectangle(
            -rd, -rd, rectWidth + 2 * rd, rectHeight + 2 * rd);
        final rect2 = PDRectangle(
            rect.lowerLeftX - rd,
            rect.lowerLeftY - rd,
            rectWidth + 2 * rd,
            rectHeight + 2 * rd);
        annot.rect = rect2.toCOSArray().toDoubleList();
      }
      pdAppearanceStream?.boundingBox = bbox;

      final halfX = rectWidth / 2;
      final halfY = rectHeight / 2;
      contentStream.moveTo(0, 0);
      contentStream.curveTo(halfX, 0, halfX, halfY, halfX, rectHeight);
      contentStream.curveTo(halfX, halfY, halfX, 0, rectWidth, 0);
      contentStream.closePath();
      contentStream.fill();
    } catch (e) {
      // LOG.error(e);
    } finally {
      contentStream?.close();
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
}
