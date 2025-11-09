/// Associates a PDF font with a FontBox-backed implementation.
class FontMapping<T> {
  FontMapping(this.font, {this.isFallback = false})
      : assert(font != null || isFallback,
            'Font mapping must provide a font or be marked as fallback.');

  /// FontBox font bound to the PDF font, or `null` when this mapping is only a fallback hint.
  final T? font;

  /// Indicates whether the mapping is a fallback selection rather than an exact match.
  final bool isFallback;

  /// Returns `true` when a concrete font instance is available.
  bool get hasFont => font != null;
}
