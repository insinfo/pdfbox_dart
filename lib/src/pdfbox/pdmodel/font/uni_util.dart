/// Utility helpers for Unicode name fallbacks.
class UniUtil {
  UniUtil._();

  /// Returns the "uniXXXX" glyph name for the given [codePoint].
  static String getUniNameOfCodePoint(int codePoint) {
    final hex = codePoint.toRadixString(16).toUpperCase();
    switch (hex.length) {
      case 1:
        return 'uni000$hex';
      case 2:
        return 'uni00$hex';
      case 3:
        return 'uni0$hex';
      default:
        return 'uni$hex';
    }
  }
}
