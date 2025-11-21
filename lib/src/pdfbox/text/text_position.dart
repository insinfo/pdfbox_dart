import 'package:logging/logging.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../pdmodel/font/pdfont.dart';
import '../util/matrix.dart';

/// This represents a string and a position on the screen of those characters.
class TextPosition {
  static final Logger _log = Logger('TextPosition');

  static final Map<int, String> _diacritics = _createDiacritics();
  static const List<List<int>> _combiningMarkRanges = [
    [0x0300, 0x036F], // Combining Diacritical Marks
    [0x1AB0, 0x1AFF], // Combining Diacritical Marks Extended
    [0x1DC0, 0x1DFF], // Combining Diacritical Marks Supplement
    [0x20D0, 0x20FF], // Combining Diacritical Marks for Symbols
    [0xFE20, 0xFE2F], // Combining Half Marks
  ];

  // text matrix for the start of the text object, coordinates are in display units
  // and have not been adjusted
  final Matrix textMatrix;

  // ending X and Y coordinates in display units
  final double endX;
  final double endY;

  final double maxHeight; // maximum height of text, in display units
  final int rotation; // 0, 90, 180, 270 degrees of page rotation
  late final double x;
  late final double y;
  final double pageHeight;
  final double pageWidth;

  final double widthOfSpace; // width of a space, in display units

  final List<int> charCodes; // internal PDF character codes
  final PDFont? font;
  final double fontSize;
  final int fontSizePt;

  // mutable
  late List<double> widths;
  late String unicode;
  double _direction = -1;

  /// Constructor.
  ///
  /// [pageRotation] rotation of the page that the text is located in
  /// [pageWidth] width of the page that the text is located in
  /// [pageHeight] height of the page that the text is located in
  /// [textMatrix] text rendering matrix for start of text (in display units)
  /// [endX] x coordinate of the end position
  /// [endY] y coordinate of the end position
  /// [maxHeight] Maximum height of text (in display units)
  /// [individualWidth] The width of the given character/string. (in text units)
  /// [spaceWidth] The width of the space character. (in display units)
  /// [unicode] The string of Unicode characters to be displayed.
  /// [charCodes] An array of the internal PDF character codes for the glyphs in this text.
  /// [font] The current font for this text position.
  /// [fontSize] The new font size.
  /// [fontSizeInPt] The font size in pt units.
  TextPosition({
    required int pageRotation,
    required this.pageWidth,
    required this.pageHeight,
    required this.textMatrix,
    required this.endX,
    required this.endY,
    required this.maxHeight,
    required double individualWidth,
    required double spaceWidth,
    required String unicode,
    required List<int> charCodes,
    this.font,
    required this.fontSize,
    required this.fontSizePt,
  })  : rotation = pageRotation,
        widthOfSpace = spaceWidth,
        charCodes = charCodes {
    this.unicode = unicode;
    widths = [individualWidth];

    x = _getXRot(rotation.toDouble());
    if (rotation == 0 || rotation == 180) {
      y = pageHeight - _getYLowerLeftRot(rotation.toDouble());
    } else {
      y = pageWidth - _getYLowerLeftRot(rotation.toDouble());
    }
  }

  // Adds non-decomposing diacritics to the hash with their related combining character.
  static Map<int, String> _createDiacritics() {
    final map = <int, String>{};
    map[0x0060] = "\u0300";
    map[0x02CB] = "\u0300";
    map[0x0027] = "\u0301";
    map[0x02B9] = "\u0301";
    map[0x02CA] = "\u0301";
    map[0x005e] = "\u0302";
    map[0x02C6] = "\u0302";
    map[0x007E] = "\u0303";
    map[0x02C9] = "\u0304";
    map[0x00B0] = "\u030A";
    map[0x02BA] = "\u030B";
    map[0x02C7] = "\u030C";
    map[0x02C8] = "\u030D";
    map[0x0022] = "\u030E";
    map[0x02BB] = "\u0312";
    map[0x02BC] = "\u0313";
    map[0x0486] = "\u0313";
    map[0x055A] = "\u0313";
    map[0x02BD] = "\u0314";
    map[0x0485] = "\u0314";
    map[0x0559] = "\u0314";
    map[0x02D4] = "\u031D";
    map[0x02D5] = "\u031E";
    map[0x02D6] = "\u031F";
    map[0x02D7] = "\u0320";
    map[0x02B2] = "\u0321";
    map[0x02CC] = "\u0329";
    map[0x02B7] = "\u032B";
    map[0x02CD] = "\u0331";
    map[0x005F] = "\u0332";
    map[0x204E] = "\u0359";
    return map;
  }

  /// Return the string of characters stored in this object.
  String getUnicode() {
    return unicode;
  }

  /// Same as [getUnicode] except that returned text is ensured to be
  /// visually ordered.
  ///
  /// Note: Dart's Bidi support might be needed here if we want full parity.
  /// For now, we return unicode as is or implement basic reversal if needed.
  /// The Java code uses Character.getDirectionality.
  String getVisuallyOrderedUnicode() {
    // TODO: Implement Bidi logic if needed.
    // For now, just return the unicode string.
    return unicode;
  }

  /// Return the internal PDF character codes of the glyphs in this text.
  List<int> getCharacterCodes() {
    return charCodes;
  }

  /// The matrix containing the starting text position and scaling.
  Matrix getTextMatrix() {
    return textMatrix;
  }

  /// Return the direction/orientation of the string in this object based on its text matrix.
  double getDir() {
    if (_direction < 0) {
      double a = textMatrix.scaleY;
      double b = textMatrix.shearY;
      double c = textMatrix.shearX;
      double d = textMatrix.scaleX;

      // 12 0   left to right
      // 0 12
      if (a > 0 && b.abs() < d && c.abs() < a && d > 0) {
        _direction = 0;
      }
      // -12 0   right to left (upside down)
      // 0 -12
      else if (a < 0 && b.abs() < d.abs() && c.abs() < a.abs() && d < 0) {
        _direction = 180;
      }
      // 0  12    up
      // -12 0
      else if (a.abs() < c.abs() && b > 0 && c < 0 && d.abs() < b) {
        _direction = 90;
      }
      // 0  -12   down
      // 12 0
      else if (a.abs() < c && b < 0 && c > 0 && d.abs() < b.abs()) {
        _direction = 270;
      } else {
        _direction = 0;
      }
    }
    return _direction;
  }

  double _getXRot(double rotation) {
    if (rotation == 0) {
      return textMatrix.translateX;
    } else if (rotation == 90) {
      return textMatrix.translateY;
    } else if (rotation == 180) {
      return pageWidth - textMatrix.translateX;
    } else if (rotation == 270) {
      return pageHeight - textMatrix.translateY;
    }
    return 0;
  }

  /// This will get the page rotation adjusted x position of the character.
  double getX() {
    return x;
  }

  /// This will get the text direction adjusted x position of the character.
  double getXDirAdj() {
    return _getXRot(getDir());
  }

  double _getYLowerLeftRot(double rotation) {
    if (rotation == 0) {
      return textMatrix.translateY;
    } else if (rotation == 90) {
      return pageWidth - textMatrix.translateX;
    } else if (rotation == 180) {
      return pageHeight - textMatrix.translateY;
    } else if (rotation == 270) {
      return textMatrix.translateX;
    }
    return 0;
  }

  /// This will get the page rotation adjusted y position of the character.
  double getY() {
    return y;
  }

  /// This will get the y position of the text, adjusted so that 0,0 is upper left.
  double getYDirAdj() {
    double dir = getDir();
    // some PDFBox code assumes that the 0,0 point is in upper left, not lower left
    if (dir == 0 || dir == 180) {
      return pageHeight - _getYLowerLeftRot(dir);
    } else {
      return pageWidth - _getYLowerLeftRot(dir);
    }
  }

  double _getWidthRot(double rotation) {
    if (rotation == 90 || rotation == 270) {
      return (endY - textMatrix.translateY).abs();
    } else {
      return (endX - textMatrix.translateX).abs();
    }
  }

  /// This will get the width of the string when page rotation adjusted coordinates are used.
  double getWidth() {
    return _getWidthRot(rotation.toDouble());
  }

  /// This will get the width of the string when text direction adjusted coordinates are used.
  double getWidthDirAdj() {
    return _getWidthRot(getDir());
  }

  /// This will get the maximum height of all characters in this string.
  double getHeight() {
    return maxHeight;
  }

  /// This will get the maximum height of all characters in this string.
  double getHeightDir() {
    return maxHeight;
  }

  /// This will get the font size that has been set with the "Tf" operator.
  double getFontSize() {
    return fontSize;
  }

  /// This will get the font size in pt.
  int getFontSizeInPt() {
    return fontSizePt;
  }

  /// This will get the font for the text being drawn.
  PDFont? getFont() {
    return font;
  }

  /// This will get the width of a space character.
  double getWidthOfSpace() {
    return widthOfSpace;
  }

  /// This will get the X scaling factor.
  double getXScale() {
    return textMatrix.scalingFactorX;
  }

  /// This will get the Y scaling factor.
  double getYScale() {
    return textMatrix.scalingFactorY;
  }

  /// Get the widths of each individual character.
  List<double> getIndividualWidths() {
    return widths;
  }

  /// Determine if this TextPosition logically contains another.
  bool contains(TextPosition tp2) {
    double thisXstart = getXDirAdj();
    double thisWidth = getWidthDirAdj();
    double thisXend = thisXstart + thisWidth;

    double tp2Xstart = tp2.getXDirAdj();
    double tp2Xend = tp2Xstart + tp2.getWidthDirAdj();

    // no X overlap at all so return as soon as possible
    if (tp2Xend <= thisXstart || tp2Xstart >= thisXend) {
      return false;
    }

    // no Y overlap at all so return as soon as possible.
    double thisYstart = getYDirAdj();
    double tp2Ystart = tp2.getYDirAdj();
    if (tp2Ystart + tp2.getHeightDir() < thisYstart ||
        tp2Ystart > thisYstart + getHeightDir()) {
      return false;
    }
    // we're going to calculate the percentage of overlap
    else if (tp2Xstart > thisXstart && tp2Xend > thisXend) {
      double overlap = thisXend - tp2Xstart;
      double overlapPercent = overlap / thisWidth;
      return overlapPercent > .15;
    } else if (tp2Xstart < thisXstart && tp2Xend < thisXend) {
      double overlap = tp2Xend - thisXstart;
      double overlapPercent = overlap / thisWidth;
      return overlapPercent > .15;
    }
    return true;
  }

  /// Determine if this TextPosition perfectly contains another.
  bool completelyContains(TextPosition tp2) {
    double thisLeft = getXDirAdj();
    double thisWidth = getWidthDirAdj();
    double thisRight = thisLeft + thisWidth;

    double tp2Left = tp2.getXDirAdj();
    double tp2Width = tp2.getWidthDirAdj();
    double tp2Right = tp2Left + tp2Width;

    if (thisLeft > tp2Left || tp2Right > thisRight) {
      return false;
    }

    double thisTop = getYDirAdj();
    double thisHeight = getHeightDir();
    double thisBottom = thisTop + thisHeight;

    double tp2Top = tp2.getYDirAdj();
    double tp2Height = tp2.getHeightDir();
    double tp2Bottom = tp2Top + tp2Height;

    if (thisTop > tp2Top || tp2Bottom > thisBottom) {
      return false;
    }

    return true;
  }

  /// Merge a single character TextPosition into the current object.
  void mergeDiacritic(TextPosition diacritic) {
    if (diacritic.getUnicode().length > 1) {
      return;
    }

    double diacXStart = diacritic.getXDirAdj();
    double diacXEnd = diacXStart + diacritic.widths[0];

    double currCharXStart = getXDirAdj();

    int strLen = unicode.length;
    bool wasAdded = false;

    for (int i = 0; i < strLen && !wasAdded; i++) {
      if (i >= widths.length) {
        _log.info(
            "diacritic ${diacritic.getUnicode()} on ligature $unicode is not supported yet and is ignored (PDFBOX-2831)");
        break;
      }
      double currCharXEnd = currCharXStart + widths[i];

      // this is the case where there is an overlap of the diacritic character with the
      // current character and the previous character.
      if (diacXStart < currCharXStart && diacXEnd <= currCharXEnd) {
        if (i == 0) {
          _insertDiacritic(i, diacritic);
        } else {
          double distanceOverlapping1 = diacXEnd - currCharXStart;
          double percentage1 = distanceOverlapping1 / widths[i];

          double distanceOverlapping2 = currCharXStart - diacXStart;
          double percentage2 = distanceOverlapping2 / widths[i - 1];

          if (percentage1 >= percentage2) {
            _insertDiacritic(i, diacritic);
          } else {
            _insertDiacritic(i - 1, diacritic);
          }
        }
        wasAdded = true;
      }
      // diacritic completely covers this character
      else if (diacXStart < currCharXStart) {
        _insertDiacritic(i, diacritic);
        wasAdded = true;
      }
      // otherwise, The diacritic modifies this character
      else if (diacXEnd <= currCharXEnd) {
        _insertDiacritic(i, diacritic);
        wasAdded = true;
      }
      // last character in the TextPosition so we add diacritic to the end
      else if (i == strLen - 1) {
        _insertDiacritic(i, diacritic);
        wasAdded = true;
      }

      // couldn't find anything useful so we go to the next character in the TextPosition
      currCharXStart += widths[i];
    }
  }

  void _insertDiacritic(int i, TextPosition diacritic) {
    StringBuffer sb = StringBuffer();
    sb.write(unicode.substring(0, i));

    List<double> widths2 = List<double>.filled(widths.length + 1, 0);
    List.copyRange(widths2, 0, widths, 0, i);

    // First we add a zero-width entry for the diacritic in the widths array
    widths2[i] = widths[i];
    widths2[i + 1] = 0;
    List.copyRange(widths2, i + 2, widths, i + 1);

    // Unicode combining diacritics always go after the base character
    sb.write(unicode[i]);

    // If a surrogate starts at the current position, make sure we preserve it
    // Dart strings are UTF-16, so we can check surrogates.
    if (i < unicode.length - 1) {
      int codeUnit = unicode.codeUnitAt(i);
      if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
        // High surrogate
        int nextCodeUnit = unicode.codeUnitAt(i + 1);
        if (nextCodeUnit >= 0xDC00 && nextCodeUnit <= 0xDFFF) {
          // Low surrogate
          sb.write(unicode[i + 1]);
          i++;
        }
      }
    }

    sb.write(_combineDiacritic(diacritic.getUnicode()));

    // get the rest of the string
    sb.write(unicode.substring(i + 1));

    unicode = sb.toString();
    widths = widths2;
  }

  String _combineDiacritic(String str) {
    if (str.isEmpty) return str;
    int codePoint = str.runes.first;

    if (_diacritics.containsKey(codePoint)) {
      return _diacritics[codePoint]!;
    } else {
      return unorm.nfkc(str).trim();
    }
  }

  static bool _isCombiningMark(int codePoint) {
    for (final range in _combiningMarkRanges) {
      final start = range[0];
      final end = range[1];
      if (codePoint >= start && codePoint <= end) {
        return true;
      }
    }
    return false;
  }

  /// @return True if the current character is a diacritic char.
  bool isDiacritic() {
    final text = getUnicode();
    if (text.isEmpty || text == 'ー') {
      return false;
    }

    final iterator = text.runes.iterator;
    if (!iterator.moveNext()) {
      return false;
    }
    final codePoint = iterator.current;
    if (iterator.moveNext()) {
      // Multi-codepoint glyphs are unlikely to be pure diacritics.
      return false;
    }

    if (_diacritics.containsKey(codePoint)) {
      return true;
    }
    return _isCombiningMark(codePoint);
  }

  @override
  String toString() {
    return getUnicode();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TextPosition) return false;

    return other.endX == endX &&
        other.endY == endY &&
        other.maxHeight == maxHeight &&
        other.rotation == rotation &&
        other.x == x &&
        other.y == y &&
        other.pageHeight == pageHeight &&
        other.pageWidth == pageWidth &&
        other.widthOfSpace == widthOfSpace &&
        other.fontSize == fontSize &&
        other.fontSizePt == fontSizePt &&
        other.textMatrix == textMatrix &&
        _listEquals(other.charCodes, charCodes) &&
        other.font == font;
  }

  @override
  int get hashCode {
    return Object.hash(
      textMatrix,
      endX,
      endY,
      maxHeight,
      rotation,
      x,
      y,
      pageHeight,
      pageWidth,
      widthOfSpace,
      Object.hashAll(charCodes),
      font,
      fontSize,
      fontSizePt,
    );
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// Helper for boolean type which doesn't exist in Dart
typedef boolean = bool;
