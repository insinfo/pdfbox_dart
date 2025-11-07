import '../io/ttf_data_stream.dart';
import 'cff_table.dart';
import 'glyph_substitution_table.dart';
import 'glyph_table.dart';
import 'otl_table.dart';
import 'true_type_font.dart';

/// Basic representation of an OpenType font (OTF/TTF hybrid).
///
/// The class currently tracks whether the font uses PostScript outlines so
/// higher level code can branch appropriately. The full API from the Java
/// implementation will be ported alongside the remaining OTF modules.
class OpenTypeFont extends TrueTypeFont {
  OpenTypeFont(TtfDataStream data) : super(data: data);

  static const int _ottoTag = 0x4F54544F; // 'OTTO'

  bool _hasPostScriptSfntTag = false;

  void setRawVersion(int rawVersion) {
    _hasPostScriptSfntTag = rawVersion == _ottoTag;
  }

  @override
  void setVersion(double value) {
    super.setVersion(value);
    if (value > 1000 && !_hasPostScriptSfntTag) {
      // Fallback detection when only the fixed-point value is available.
      _hasPostScriptSfntTag = true;
    }
  }

  /// Returns true if the font declares PostScript outlines.
  bool get isPostScript =>
      _hasPostScriptSfntTag ||
      tableMap.containsKey(CffTable.tableTag) ||
      tableMap.containsKey('CFF2');

  /// Returns true if the font is supported by the current subset of the port.
  bool get isSupportedOtf => !(_hasPostScriptSfntTag &&
      !tableMap.containsKey(CffTable.tableTag) &&
      tableMap.containsKey('CFF2'));

  /// Returns true when any advanced OpenType layout table is present.
  bool get hasLayoutTables =>
      tableMap.containsKey('BASE') ||
      tableMap.containsKey('GDEF') ||
      tableMap.containsKey('GPOS') ||
      tableMap.containsKey(GlyphSubstitutionTable.tableTag) ||
      tableMap.containsKey(OtlTable.tableTag);

  /// Returns the decoded CFF table for fonts that declare PostScript outlines.
  CffTable getCffTable() {
    if (!isPostScript) {
      throw UnsupportedError('TTF fonts do not expose a CFF table');
    }
    final table = tableMap[CffTable.tableTag];
    if (table is! CffTable) {
      throw StateError('CFF table is missing or has not been initialised');
    }
    return table;
  }

  @override
  GlyphTable? getGlyphTable() {
    if (isPostScript) {
      throw UnsupportedError(
          'OTF fonts with PostScript outlines do not expose a glyf table');
    }
    return super.getGlyphTable();
  }
}
