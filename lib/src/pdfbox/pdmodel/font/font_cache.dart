import 'dart:collection';

import '../../../fontbox/font_box_font.dart';
import 'font_info.dart';

/// In-memory cache for system fonts provided by a [FontProvider].
class FontCache {
  FontCache({this.capacity = 32})
      : assert(capacity > 0, 'Cache capacity must be positive');

  final int capacity;
  final LinkedHashMap<FontInfo, FontBoxFont> _cache =
      LinkedHashMap<FontInfo, FontBoxFont>();

  /// Stores the [font] instance associated with [info] and evicts the least recently
  /// used entry when the cache exceeds its [capacity].
  void addFont(FontInfo info, FontBoxFont font) {
    final existing = _cache.remove(info);
    if (existing != null) {
      _dispose(existing);
    }

    _cache[info] = font;

    if (_cache.length <= capacity) {
      return;
    }

    final oldestKey = _cache.keys.first;
    final oldestFont = _cache.remove(oldestKey);
    if (oldestFont != null) {
      _dispose(oldestFont);
    }
  }

  /// Retrieves the cached font for [info] when available, marking it as recently used.
  FontBoxFont? getFont(FontInfo info) {
    final font = _cache.remove(info);
    if (font != null) {
      _cache[info] = font;
    }
    return font;
  }

  /// Clears every cached entry and releases associated resources when possible.
  void clear() {
    final fonts = _cache.values.toList(growable: false);
    _cache.clear();
    for (final font in fonts) {
      _dispose(font);
    }
  }

  void _dispose(FontBoxFont font) {
    // Intentionally left blank. Fonts may still be referenced by callers
    // even after eviction, so we cannot eagerly close underlying resources yet.
  }
}
