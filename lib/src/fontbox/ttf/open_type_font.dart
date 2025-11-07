import '../io/ttf_data_stream.dart';
import 'cff_table.dart';
import 'glyph_table.dart';
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

  @override
  GlyphTable? getGlyphTable() {
    if (_hasPostScriptSfntTag) {
      throw UnsupportedError(
          'OTF fonts with PostScript outlines do not expose a glyf table');
    }
    return super.getGlyphTable();
  }
}
