import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Minimal SASLprep implementation mirroring the PDFBox helper for revision 6 passwords.
class SaslPrep {
  SaslPrep._();

  /// Applies SASLprep using the "query" profile (allows unassigned code points).
  static String saslPrepQuery(String value) {
    return _saslPrep(value, allowUnassigned: true);
  }

  /// Applies SASLprep using the "stored" profile (rejects unassigned code points).
  static String saslPrepStored(String value) {
    return _saslPrep(value, allowUnassigned: false);
  }

  static String _saslPrep(String value, {required bool allowUnassigned}) {
    if (value.isEmpty) {
      return value;
    }

    final mapped = <int>[];
    for (final codepoint in value.runes) {
      if (_nonAsciiSpace(codepoint)) {
        mapped.add(0x20);
      } else if (!_mappedToNothing(codepoint)) {
        mapped.add(codepoint);
      }
    }

    final normalized = unorm.nfkc(String.fromCharCodes(mapped));
    if (normalized.isEmpty) {
      return normalized;
    }

    final runes = normalized.runes.toList(growable: false);
    var containsRandAL = false;
    var containsL = false;
    var firstIsRandAL = false;
    var lastIsRandAL = false;

    for (var i = 0; i < runes.length; i++) {
      final codepoint = runes[i];
      if (_prohibited(codepoint)) {
        final hex = codepoint.toRadixString(16).padLeft(4, '0');
        throw ArgumentError('Prohibited character U+$hex at index $i');
      }
      if (!allowUnassigned && !_isDefined(codepoint)) {
        final hex = codepoint.toRadixString(16).padLeft(4, '0');
        throw ArgumentError('Character U+$hex at index $i is unassigned');
      }

      final isRandAL = _isRandALCat(codepoint);
      final isLCat = _isLCat(codepoint);
      if (i == 0) {
        firstIsRandAL = isRandAL;
      }
      if (i == runes.length - 1) {
        lastIsRandAL = isRandAL;
      }
      containsRandAL |= isRandAL;
      containsL |= isLCat;
    }

    if (containsRandAL && containsL) {
      throw ArgumentError(
          'Contains both RandALCat characters and LCat characters');
    }
    if (firstIsRandAL && !lastIsRandAL) {
      throw ArgumentError(
          'First character is RandALCat, but last character is not');
    }
    return normalized;
  }

  static bool _prohibited(int codepoint) {
    return _nonAsciiSpace(codepoint) ||
        _asciiControl(codepoint) ||
        _nonAsciiControl(codepoint) ||
        _privateUse(codepoint) ||
        _nonCharacterCodePoint(codepoint) ||
        _surrogateCodePoint(codepoint) ||
        _inappropriateForPlainText(codepoint) ||
        _inappropriateForCanonical(codepoint) ||
        _changeDisplayProperties(codepoint) ||
        _tagging(codepoint);
  }

  static bool _tagging(int codepoint) {
    return codepoint == 0xE0001 ||
        (codepoint >= 0xE0020 && codepoint <= 0xE007F);
  }

  static bool _changeDisplayProperties(int codepoint) {
    return codepoint == 0x0340 ||
        codepoint == 0x0341 ||
        codepoint == 0x200E ||
        codepoint == 0x200F ||
        codepoint == 0x202A ||
        codepoint == 0x202B ||
        codepoint == 0x202C ||
        codepoint == 0x202D ||
        codepoint == 0x202E ||
        (codepoint >= 0x206A && codepoint <= 0x206F);
  }

  static bool _inappropriateForCanonical(int codepoint) {
    return codepoint >= 0x2FF0 && codepoint <= 0x2FFB;
  }

  static bool _inappropriateForPlainText(int codepoint) {
    return codepoint >= 0xFFF9 && codepoint <= 0xFFFD;
  }

  static bool _surrogateCodePoint(int codepoint) {
    return codepoint >= 0xD800 && codepoint <= 0xDFFF;
  }

  static bool _nonCharacterCodePoint(int codepoint) {
    return (codepoint >= 0xFDD0 && codepoint <= 0xFDEF) ||
        (codepoint & 0xFFFE) == 0xFFFE && codepoint <= 0x10FFFF;
  }

  static bool _privateUse(int codepoint) {
    return (codepoint >= 0xE000 && codepoint <= 0xF8FF) ||
        (codepoint >= 0xF0000 && codepoint <= 0xFFFFD) ||
        (codepoint >= 0x100000 && codepoint <= 0x10FFFD);
  }

  static bool _nonAsciiControl(int codepoint) {
    return (codepoint >= 0x0080 && codepoint <= 0x009F) ||
        codepoint == 0x06DD ||
        codepoint == 0x070F ||
        codepoint == 0x180E ||
        codepoint == 0x200C ||
        codepoint == 0x200D ||
        codepoint == 0x2028 ||
        codepoint == 0x2029 ||
        (codepoint >= 0x2060 && codepoint <= 0x2063) ||
        (codepoint >= 0x206A && codepoint <= 0x206F) ||
        codepoint == 0xFEFF ||
        (codepoint >= 0xFFF9 && codepoint <= 0xFFFC) ||
        (codepoint >= 0x1D173 && codepoint <= 0x1D17A);
  }

  static bool _asciiControl(int codepoint) {
    return (codepoint >= 0x0000 && codepoint <= 0x001F) || codepoint == 0x007F;
  }

  static bool _nonAsciiSpace(int codepoint) {
    return codepoint == 0x00A0 ||
        codepoint == 0x1680 ||
        (codepoint >= 0x2000 && codepoint <= 0x200B) ||
        codepoint == 0x202F ||
        codepoint == 0x205F ||
        codepoint == 0x3000;
  }

  static bool _mappedToNothing(int codepoint) {
    return codepoint == 0x00AD ||
        codepoint == 0x034F ||
        codepoint == 0x1806 ||
        (codepoint >= 0x180B && codepoint <= 0x180D) ||
        codepoint == 0x200B ||
        codepoint == 0x200C ||
        codepoint == 0x200D ||
        codepoint == 0x2060 ||
        (codepoint >= 0xFE00 && codepoint <= 0xFE0F) ||
        codepoint == 0xFEFF;
  }

  static bool _isRandALCat(int codepoint) {
    return _inRangeList(codepoint, _randALCatRanges);
  }

  static bool _isLCat(int codepoint) {
    return (codepoint >= 0x0041 && codepoint <= 0x005A) ||
        (codepoint >= 0x0061 && codepoint <= 0x007A) ||
        (codepoint >= 0x00C0 && codepoint <= 0x02AF) ||
        (codepoint >= 0x0370 && codepoint <= 0x052F) ||
        (codepoint >= 0x1E00 && codepoint <= 0x1FFF);
  }

  static bool _isDefined(int codepoint) {
    if (codepoint < 0 || codepoint > 0x10FFFF) {
      return false;
    }
    if (_surrogateCodePoint(codepoint) || _nonCharacterCodePoint(codepoint)) {
      return false;
    }
    return true;
  }

  static bool _inRangeList(int codepoint, List<int> ranges) {
    for (var i = 0; i < ranges.length; i += 2) {
      final start = ranges[i];
      final end = ranges[i + 1];
      if (codepoint >= start && codepoint <= end) {
        return true;
      }
    }
    return false;
  }

  static const List<int> _randALCatRanges = <int>[
    0x0590,
    0x05FF,
    0x0600,
    0x06FF,
    0x0700,
    0x077F,
    0x0780,
    0x07BF,
    0x07C0,
    0x08FF,
    0xFB1D,
    0xFDFF,
    0xFE70,
    0xFEFF,
    0x10800,
    0x10FFF,
    0x1EE00,
    0x1EEFF,
  ];
}
