import '../../../pd_document.dart';
import '../pd_annotation.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the link annotations appearance.
///
/// Link annotations typically don't need an appearance stream as they
/// are interactive elements that respond to clicks. However, some PDFs
/// may want to show a visible indication of the link area.
class PDLinkAppearanceHandler extends PDAbstractAppearanceHandler {
  PDLinkAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    // Link annotations usually don't have a visible appearance
    // The highlight mode (/H) determines how the link appears when activated:
    // - N: None
    // - I: Invert (most common)
    // - O: Outline
    // - P: Push
    //
    // The border can be controlled via /Border or /BS entries
    // For now, this is left as a no-op as most viewers handle links internally
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
