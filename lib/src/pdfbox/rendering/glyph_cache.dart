import 'package:dart_graphics/dart_graphics.dart';
import 'package:logging/logging.dart';

import '../pdmodel/font/pd_vector_font.dart';
import '../../fontbox/cff/char_string_path.dart';

/// Port of PDFBox's `GlyphCache`.
///
/// Caches glyph outlines in normalized glyph space for a given [PDVectorFont].
final class GlyphCache {
  GlyphCache(this.font);

  static final Logger _log = Logger('pdfbox.rendering.GlyphCache');

  final PDVectorFont font;
  final Map<int, VertexStorage> _cache = <int, VertexStorage>{};

  VertexStorage getPathForCharacterCode(int code) {
    final cached = _cache[code];
    if (cached != null) {
      return cached;
    }

    try {
      if (!font.hasGlyph(code)) {
        _log.fine('No glyph for code $code in font');
      }

      final charPath = font.getNormalizedPath(code);
      final outline = _charStringPathToVertexStorage(charPath);
      _cache[code] = outline;
      return outline;
    } catch (e, st) {
      _log.warning('Glyph rendering failed for code $code', e, st);
      final empty = VertexStorage();
      _cache[code] = empty;
      return empty;
    }
  }

  VertexStorage _charStringPathToVertexStorage(CharStringPath path) {
    final out = VertexStorage();
    for (final command in path.commands) {
      switch (command) {
        case MoveToCommand(:final x, :final y):
          out.moveTo(x, y);
          break;
        case LineToCommand(:final x, :final y):
          out.lineTo(x, y);
          break;
        case CurveToCommand(
            :final x1,
            :final y1,
            :final x2,
            :final y2,
            :final x3,
            :final y3,
          ):
          out.curve4(x1, y1, x2, y2, x3, y3);
          break;
        case ClosePathCommand():
          out.closePath();
          break;
      }
    }
    return out;
  }
}
