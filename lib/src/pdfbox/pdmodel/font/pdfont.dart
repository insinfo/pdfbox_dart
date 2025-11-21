import '../../../fontbox/afm/font_metrics.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../util/matrix.dart';
import 'encoding/glyph_list.dart';
import 'standard14_fonts.dart';
import 'pd_font_descriptor.dart';

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

  /// Returns the font descriptor when available.
  PDFontDescriptor? get fontDescriptor {
    final dictionary = cosObject.getCOSDictionary(COSName.fontDescriptor);
    if (dictionary != null) {
      return PDFontDescriptor(dictionary);
    }
    return null;
  }

  /// Resolves a Unicode representation for the supplied glyph code.
  String? toUnicode(int code);

  /// Provides the font-specific width for a single glyph code.
  double getWidthFromFont(int code);

  /// Returns the width of the space character.
  double getSpaceWidth() {
    // TODO: Check ToUnicode CMap for space mapping if available
    return getWidthFromFont(32);
  }

  /// Returns the average font width.
  double getAverageFontWidth() {
    final descriptor = fontDescriptor;
    if (descriptor != null) {
      final avg = descriptor.avgWidth;
      if (avg != null && avg != 0) {
        return avg;
      }
    }
    final metrics = standard14Metrics;
    if (metrics != null) {
      return metrics.getAverageCharacterWidth();
    }
    return 0;
  }

  /// Returns the font matrix, which transforms glyph space to text space.
  Matrix get fontMatrix {
    final array = dictionary.getCOSArray(COSName.fontMatrix);
    if (array != null) {
      return Matrix.fromCos(array);
    }
    return Matrix.getScaleInstance(0.001, 0.001);
  }
}
