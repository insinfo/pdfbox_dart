import '../../../fontbox/afm/font_metrics.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'encoding/glyph_list.dart';
import 'standard14_fonts.dart';

/// Base class for PDModel fonts wrapping a COS font dictionary.
abstract class PDFont {
  PDFont(
    this.dictionary, {
    Standard14Font? standard14Font,
  })  : _glyphList = GlyphList.getAdobeGlyphList(),
        _standard14Font = standard14Font;

  final COSDictionary dictionary;
  GlyphList _glyphList;
  Standard14Font? _standard14Font;

  /// Exposes the underlying COS dictionary.
  COSDictionary get cosObject => dictionary;

  /// Returns the PostScript base font name when available.
  String? get name => dictionary.getNameAsString(COSName.baseFont);

  /// Indicates whether this font belongs to the PDF standard 14 set.
  bool get isStandard14 => standard14Font != null;

  /// Retrieves the lazily loaded standard 14 descriptor when applicable.
  Standard14Font? get standard14Font {
    final cached = _standard14Font;
    if (cached != null) {
      return cached;
    }
    final resolved = Standard14Fonts.byPostScriptName(name);
    _standard14Font = resolved;
    return resolved;
  }

  /// Returns the font metrics associated with the standard 14 font, if any.
  FontMetrics? get standard14Metrics => standard14Font?.metrics;

  /// Returns the glyph list used for Unicode conversions.
  GlyphList get glyphList => _glyphList;

  set glyphList(GlyphList value) {
    _glyphList = value;
  }

  /// Resolves a Unicode representation for the supplied glyph code.
  String? toUnicode(int code);

  /// Provides the font-specific width for a single glyph code.
  double getWidthFromFont(int code);
}
