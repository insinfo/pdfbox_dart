/// Interface for appearance generation.
abstract class PDAppearanceHandler {
  void generateAppearanceStreams();

  void generateNormalAppearance();

  void generateRolloverAppearance();

  void generateDownAppearance();
}
