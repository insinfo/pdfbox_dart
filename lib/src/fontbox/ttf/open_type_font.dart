import '../../io/exceptions.dart';
import '../cff/cff_font.dart' show CFFCIDFont, CFFType1Font;
import '../cff/char_string_path.dart' as cff;
import '../io/ttf_data_stream.dart';
import 'cff_table.dart';
import 'glyph_renderer.dart';
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
  GlyphPath getPath(String name) {
    if (!isPostScript || !isSupportedOtf) {
      return super.getPath(name);
    }

    final gid = nameToGid(name);
    if (gid <= 0) {
      return GlyphPath();
    }

    try {
      final cffFont = getCffTable().font;
      if (cffFont is CFFType1Font) {
        final outline = cffFont.getType2CharString(gid).getPath();
        return _toGlyphPath(outline);
      }
      if (cffFont is CFFCIDFont) {
        final cid = cffFont.charset.getCIDForGID(gid);
        if (cid <= 0) {
          return GlyphPath();
        }
        final outline = cffFont.getType2CharString(cid).getPath();
        return _toGlyphPath(outline);
      }
      return GlyphPath();
    } on IOException {
      return GlyphPath();
    } on Exception {
      return GlyphPath();
    } on StateError {
      return GlyphPath();
    }
  }

  GlyphPath _toGlyphPath(cff.CharStringPath outline) {
    final glyphPath = GlyphPath();
    for (final command in outline.commands) {
      if (command is cff.MoveToCommand) {
        glyphPath.moveTo(command.x, command.y);
      } else if (command is cff.LineToCommand) {
        glyphPath.lineTo(command.x, command.y);
      } else if (command is cff.CurveToCommand) {
        glyphPath.curveTo(
          command.x1,
          command.y1,
          command.x2,
          command.y2,
          command.x3,
          command.y3,
        );
      } else if (command is cff.ClosePathCommand) {
        glyphPath.closePath();
      }
    }
    return glyphPath;
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
