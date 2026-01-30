import '../../../pd_document.dart';
import '../pd_annotation.dart';
import 'pd_abstract_appearance_handler.dart';

/// Handler to generate the sound annotations appearance.
///
/// TODO: Full implementation requires:
/// - Drawing the sound icon (Speaker or Mic depending on /Name)
/// - The sound data is in a Sound object stream
class PDSoundAppearanceHandler extends PDAbstractAppearanceHandler {
  PDSoundAppearanceHandler(PDAnnotation annotation, [PDDocument? document])
      : super(annotation, document);

  @override
  void generateNormalAppearance() {
    // Sound annotations show an icon (Speaker or Mic)
    // The actual sound playing is handled by the viewer
    //
    // For now, this is a stub. Full implementation would draw:
    // - Speaker icon (default)
    // - Microphone icon (if /Name is Mic)
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
