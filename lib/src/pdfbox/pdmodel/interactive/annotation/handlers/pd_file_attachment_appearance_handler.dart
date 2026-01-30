import '../../../pd_document.dart';
import '../pd_annotation.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the file attachment annotations appearance.
///
/// TODO: Full implementation requires:
/// - Drawing the file attachment icon (Graph, Paperclip, PushPin, Tag)
/// - The icon type is determined by /Name entry
class PDFileAttachmentAppearanceHandler extends PDAbstractAppearanceHandler {
  PDFileAttachmentAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    // File attachment annotations show an icon representing the attachment
    // Common icon names:
    // - Graph (default)
    // - Paperclip
    // - PushPin
    // - Tag
    //
    // For now, this is a stub. Full implementation would draw
    // the appropriate icon based on /Name entry.
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
