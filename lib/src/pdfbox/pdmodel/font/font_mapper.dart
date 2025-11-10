import '../../../fontbox/font_box_font.dart';
import '../../../fontbox/ttf/true_type_font.dart';
import 'cid_font_mapping.dart';
import 'font_mapping.dart';
import 'pd_cid_system_info.dart';
import 'pd_font_descriptor.dart';

/// Maps logical PostScript font names to concrete font programs.
abstract class FontMapper {
  /// Finds a TrueType font matching [baseFont] or one of its substitutes.
  FontMapping<TrueTypeFont> getTrueTypeFont(
    String baseFont,
    PDFontDescriptor? fontDescriptor,
  );

  /// Finds any font program (PFB, TTF, OTF) matching [baseFont] or a substitute.
  FontMapping<FontBoxFont> getFontBoxFont(
    String baseFont,
    PDFontDescriptor? fontDescriptor,
  );

  /// Finds a CID-keyed font matching [baseFont] or [cidSystemInfo], or a substitute.
  CidFontMapping getCidFont(
    String baseFont,
    PDFontDescriptor? fontDescriptor,
    PDCIDSystemInfo? cidSystemInfo,
  );
}
