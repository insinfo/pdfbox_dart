import '../../../fontbox/font_box_font.dart';
import 'font_info.dart';

/// In-memory cache for system fonts provided by a [FontProvider].
class FontCache {
  FontCache();

  final Map<FontInfo, FontBoxFont> _cache = <FontInfo, FontBoxFont>{};

  /// Stores the [font] instance associated with [info].
  ///
  /// TODO: implement eviction or weak references similar to the Java soft reference cache.
  void addFont(FontInfo info, FontBoxFont font) {
    _cache[info] = font;
  }

  /// Retrieves the cached font for [info] when available.
  FontBoxFont? getFont(FontInfo info) => _cache[info];

  /// Clears every cached entry.
  void clear() => _cache.clear();
}
