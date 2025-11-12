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
