import 'package:pdfbox_dart/src/fontbox/font_box_font.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/open_type_font.dart';

import 'font_mapping.dart';

/// Font mapping specific to CID-keyed fonts, exposing an optional TrueType fallback.
class CidFontMapping extends FontMapping<OpenTypeFont> {
  CidFontMapping(
    OpenTypeFont? font,
    FontBoxFont? trueTypeFont, {
    bool isFallback = false,
  })  : _trueTypeFont = trueTypeFont,
        super(font, isFallback: isFallback);

  final FontBoxFont? _trueTypeFont;

  /// Returns the mapped TrueType font when available.
  FontBoxFont? get trueTypeFont => _trueTypeFont;

  /// Returns `true` when the mapping references a CID font program.
  bool get isCidFont => font != null;
}
