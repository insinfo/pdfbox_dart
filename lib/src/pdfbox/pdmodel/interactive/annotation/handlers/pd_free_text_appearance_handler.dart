import '../../../common/pd_rectangle.dart';
import '../../../pd_appearance_content_stream.dart';
import '../../../pd_document.dart';
import '../pd_annotation.dart';
import '../pd_annotation_free_text.dart';
import 'annotation_border.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the free text annotations appearance.
///
/// TODO: Full implementation requires:
/// - Text rendering with fonts (defaultAppearance string parsing)
/// - Multi-line text layout
/// - Text alignment (left, center, right, justified)
/// - Callout line drawing
/// - Intent handling (FreeText, FreeTextCallout, FreeTextTypeWriter)
class PDFreeTextAppearanceHandler extends PDAbstractAppearanceHandler {
  PDFreeTextAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    final annot = getAnnotation();
    if (annot is! PDAnnotationFreeText) return;

    PDRectangle? rect = annot.rectangle;
    if (rect == null) {
      return;
    }

    final ab = AnnotationBorder.getAnnotationBorder(annot, annot.borderStyle);
    final color = getColor();

    PDAppearanceContentStream? cs;
    try {
      cs = getNormalAppearanceAsContentStream();
      setOpacity(cs, annot.constantOpacity);

      // Draw background if color is set
      if (color != null && color.components.isNotEmpty) {
        cs.setNonStrokingColorPD(color);
        cs.addRect(0, 0, rect.width, rect.height);
        cs.fill();
      }

      // Draw border if width > 0
      if (ab.width > 0 && color != null) {
        cs.setStrokingColorPD(color);
        cs.setLineWidth(ab.width);
        if (ab.dashArray != null) {
          cs.setLineDashPattern(ab.dashArray!, 0);
        }
        cs.addRect(ab.width / 2, ab.width / 2, 
            rect.width - ab.width, rect.height - ab.width);
        cs.stroke();
      }

      // TODO: Render text content
      // This requires:
      // 1. Parse the default appearance string (DA) to get font and color
      // 2. Use the contents or rich contents (RC)
      // 3. Apply text alignment (Q entry)
      // 4. Handle multi-line text
      //
      // For now, leave content area empty
      
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
