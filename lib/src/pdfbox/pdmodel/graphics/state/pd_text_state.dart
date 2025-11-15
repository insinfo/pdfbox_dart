import '../../font/pdfont.dart';
import 'rendering_mode.dart';

/// Represents the text state parameters used while processing a content stream.
class PDTextState {
  PDTextState();

  double characterSpacing = 0;
  double wordSpacing = 0;
  double horizontalScaling = 100;
  double leading = 0;
  PDFont? font;
  double fontSize = 0;
  RenderingMode renderingMode = RenderingMode.fill;
  double rise = 0;
  bool knockout = true;

  double getCharacterSpacing() => characterSpacing;

  void setCharacterSpacing(double value) {
    characterSpacing = value;
  }

  double getWordSpacing() => wordSpacing;

  void setWordSpacing(double value) {
    wordSpacing = value;
  }

  double getHorizontalScaling() => horizontalScaling;

  void setHorizontalScaling(double value) {
    horizontalScaling = value;
  }

  double getLeading() => leading;

  void setLeading(double value) {
    leading = value;
  }

  RenderingMode getRenderingMode() => renderingMode;

  void setRenderingMode(RenderingMode mode) {
    renderingMode = mode;
  }

  double getRise() => rise;

  void setRise(double value) {
    rise = value;
  }

  /// Indicates whether text knockout is enabled (true by default).
  bool get knockoutFlag => knockout;

  /// Updates the knockout flag.
  void setKnockoutFlag(bool value) {
    knockout = value;
  }

  /// Produces a shallow copy of this text state.
  PDTextState clone() {
    final copy = PDTextState();
    copy.characterSpacing = characterSpacing;
    copy.wordSpacing = wordSpacing;
    copy.horizontalScaling = horizontalScaling;
    copy.leading = leading;
    copy.font = font;
    copy.fontSize = fontSize;
    copy.renderingMode = renderingMode;
    copy.rise = rise;
    copy.knockout = knockout;
    return copy;
  }
}
