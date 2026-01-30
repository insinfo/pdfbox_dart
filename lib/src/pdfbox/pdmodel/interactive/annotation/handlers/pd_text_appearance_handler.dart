import '../../../pd_document.dart';
import '../pd_annotation.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the text (note) annotations appearance.
///
/// TODO: Full implementation requires:
/// - Drawing the text note icon (Comment, Key, Note, Help, NewParagraph, Paragraph, Insert)
/// - Icon can be customized via /Name entry
/// - Support for both open and closed states
class PDTextAppearanceHandler extends PDAbstractAppearanceHandler {
  PDTextAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    // Text annotations (sticky notes) typically show a small icon
    // The actual icon depends on the /Name entry in the annotation
    // Common icons: Comment, Key, Note, Help, NewParagraph, Paragraph, Insert
    //
    // For now, this is a stub. Full implementation would need:
    // 1. Read the /Name entry to determine icon type
    // 2. Draw the appropriate icon shape
    // 3. Handle the /Open state for expanded notes
    //
    // Many PDF viewers use their own icons and may ignore the appearance stream
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
