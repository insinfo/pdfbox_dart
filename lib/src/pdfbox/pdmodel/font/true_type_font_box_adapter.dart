import '../../../fontbox/cff/char_string_path.dart' as cff_path;
import '../../../fontbox/ttf/glyph_renderer.dart' as glyph;
import '../../../fontbox/ttf/true_type_font.dart';
import '../../../fontbox/util/bounding_box.dart';
import '../../../io/exceptions.dart';
import 'package:logging/logging.dart';
import '../../../fontbox/font_box_font.dart';

/// Lightweight [FontBoxFont] wrapper backed by a parsed [TrueTypeFont].
///
/// The current implementation focuses on exposing essential metrics required
/// by PDFBox during font substitution. Outline conversion is intentionally
/// conservative and will be expanded as additional rendering features are
/// ported.
class TrueTypeFontBoxAdapter implements FontBoxFont {
  TrueTypeFontBoxAdapter(this.font)
      : _logger = Logger('pdfbox.TrueTypeFontBoxAdapter');

  final TrueTypeFont font;
  final Logger _logger;

  @override
  String getName() => font.getName() ?? 'UnknownTTF';

  @override
  BoundingBox getFontBBox() => font.getFontBBox() ?? BoundingBox();

  @override
  List<num> getFontMatrix() => List<num>.from(font.getFontMatrix());

  @override
  cff_path.CharStringPath getPath(String name) {
    final glyphTable = font.getGlyphTable();
    if (glyphTable == null) {
      return cff_path.CharStringPath();
    }

    final gid = font.nameToGid(name);
    if (gid <= 0) {
      return cff_path.CharStringPath();
    }

    try {
      final glyphData = glyphTable.getGlyph(gid);
      if (glyphData == null) {
        return cff_path.CharStringPath();
      }
      final glyphPath = glyphData.getPath();
      if (glyphPath.isEmpty) {
        return cff_path.CharStringPath();
      }
      final rawPath = _glyphPathToCharString(glyphPath);
      final units = font.unitsPerEm;
      final scale = units > 0 && units != 1000 ? 1000.0 / units : 1.0;
      return _scalePath(rawPath, scale);
    } on IOException catch (error, stackTrace) {
      _logger.warning('Failed to read glyph outline for "$name"', error, stackTrace);
    } on StateError catch (error, stackTrace) {
      _logger.warning('State error while reading glyph "$name"', error, stackTrace);
    }
    return cff_path.CharStringPath();
  }

  @override
  double getWidth(String name) {
    final unitsPerEm = font.unitsPerEm;
    if (unitsPerEm <= 0) {
      return 0;
    }
    final rawWidth = font.getWidth(name);
    return rawWidth * (1000.0 / unitsPerEm);
  }

  @override
  bool hasGlyph(String name) => font.hasGlyph(name);

  cff_path.CharStringPath _glyphPathToCharString(glyph.GlyphPath glyphPath) {
    final path = cff_path.CharStringPath();
    var currentX = 0.0;
    var currentY = 0.0;

    for (final command in glyphPath.commands) {
      if (command is glyph.MoveToCommand) {
        path.moveTo(command.x, command.y);
        currentX = command.x;
        currentY = command.y;
      } else if (command is glyph.LineToCommand) {
        path.lineTo(command.x, command.y);
        currentX = command.x;
        currentY = command.y;
      } else if (command is glyph.QuadToCommand) {
        final x1 = command.cx;
        final y1 = command.cy;
        final x2 = command.x;
        final y2 = command.y;
        final c1x = currentX + (2.0 / 3.0) * (x1 - currentX);
        final c1y = currentY + (2.0 / 3.0) * (y1 - currentY);
        final c2x = x2 + (2.0 / 3.0) * (x1 - x2);
        final c2y = y2 + (2.0 / 3.0) * (y1 - y2);
        path.curveTo(c1x, c1y, c2x, c2y, x2, y2);
        currentX = x2;
        currentY = y2;
      } else if (command is glyph.CubicToCommand) {
        path.curveTo(
          command.cx1,
          command.cy1,
          command.cx2,
          command.cy2,
          command.x,
          command.y,
        );
        currentX = command.x;
        currentY = command.y;
      } else if (command is glyph.ClosePathCommand) {
        path.closePath();
      }
    }
    return path;
  }

  cff_path.CharStringPath _scalePath(cff_path.CharStringPath path, double scale) {
    if (scale == 1.0) {
      return path.clone();
    }
    final scaled = cff_path.CharStringPath();
    for (final command in path.commands) {
      if (command is cff_path.MoveToCommand) {
        scaled.moveTo(command.x * scale, command.y * scale);
      } else if (command is cff_path.LineToCommand) {
        scaled.lineTo(command.x * scale, command.y * scale);
      } else if (command is cff_path.CurveToCommand) {
        scaled.curveTo(
          command.x1 * scale,
          command.y1 * scale,
          command.x2 * scale,
          command.y2 * scale,
          command.x3 * scale,
          command.y3 * scale,
        );
      } else if (command is cff_path.ClosePathCommand) {
        scaled.closePath();
      }
    }
    return scaled;
  }
}
