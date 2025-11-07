/// Minimal mapping between Unicode code points and OpenType script tags used by GSUB.
///
/// The original Java version loads the comprehensive script data from the Unicode
/// Scripts.txt file. To keep the initial port lightweight, we currently expose the
/// subsets required by the scripts supported via `Language` (Latin and selected
/// Indic scripts). Expanding this table to the complete dataset is tracked as a
/// follow-up task.
class OpenTypeScript {
  OpenTypeScript._();

  static const String inherited = 'Inherited';
  static const String unknown = 'Unknown';
  static const String tagDefault = 'DFLT';

  static final Map<String, List<String>> _scriptToTags = <String, List<String>>{
    'Common': const <String>[tagDefault],
    'Latin': const <String>['latn'],
    'Bengali': const <String>['bng2', 'beng'],
    'Devanagari': const <String>['dev2', 'deva'],
    'Gujarati': const <String>['gjr2', 'gujr'],
  };

  /// Returns the OpenType script tags associated with [codePoint].
  static List<String> getScriptTags(int codePoint) {
    if (codePoint < 0 || codePoint > 0x10FFFF) {
      throw ArgumentError.value(codePoint, 'codePoint', 'Invalid Unicode scalar value');
    }
    final script = _scriptForCodePoint(codePoint);
    return _scriptToTags[script] ?? const <String>[tagDefault];
  }

  static String _scriptForCodePoint(int codePoint) {
    if (_isInRange(codePoint, 0x0900, 0x097F)) {
      return 'Devanagari';
    }
    if (_isInRange(codePoint, 0x0980, 0x09FF)) {
      return 'Bengali';
    }
    if (_isInRange(codePoint, 0x0A80, 0x0AFF)) {
      return 'Gujarati';
    }
    if (_isLatin(codePoint)) {
      return 'Latin';
    }
    return 'Common';
  }

  static bool _isInRange(int value, int start, int end) => value >= start && value <= end;

  static bool _isLatin(int codePoint) {
    if (_isInRange(codePoint, 0x0041, 0x005A) || _isInRange(codePoint, 0x0061, 0x007A)) {
      return true;
    }
    if (_isInRange(codePoint, 0x00C0, 0x02AF)) {
      return true;
    }
    if (_isInRange(codePoint, 0x1E00, 0x1EFF)) {
      return true;
    }
    return false;
  }
}
