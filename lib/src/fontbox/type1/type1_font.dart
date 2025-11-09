import 'dart:collection';
import 'dart:typed_data';

import '../../io/exceptions.dart';
import '../cff/char_string_path.dart';
import '../cff/type1_char_string.dart';
import '../cff/type1_char_string_parser.dart';
import '../encoded_font.dart';
import '../encoding/encoding.dart';
import '../font_box_font.dart';
import '../util/bounding_box.dart';
import '../pfb/pfb_parser.dart';
import 'type1_char_string_reader.dart';
import 'type1_parser.dart';

/// Representation of an Adobe Type 1 font program (.pfb).
class Type1Font implements Type1CharStringReader, EncodedFont, FontBoxFont {
  static const List<num> _defaultFontMatrix = <num>[
    0.001,
    0.0,
    0.0,
    0.001,
    0.0,
    0.0
  ];

  /// Creates an empty Type 1 font. Instances are populated by [Type1Parser].
  Type1Font(Uint8List segment1, Uint8List segment2)
      : _segment1 = Uint8List.fromList(segment1),
        _segment2 = Uint8List.fromList(segment2);

  /// Parses a Type 1 font from a PFB container.
  static Type1Font createWithPfb(Uint8List pfbBytes) {
    final parser = PfbParser(pfbBytes);
    return Type1Parser().parse(parser.segment1, parser.segment2);
  }

  /// Parses a Type 1 font from raw PFB segments (ASCII + binary).
  static Type1Font createWithSegments(Uint8List segment1, Uint8List segment2) {
    return Type1Parser().parse(segment1, segment2);
  }

  // Font dictionary entries
  String fontName = '';
  Encoding? encoding;
  int paintType = 0;
  int fontType = 1;
  List<num> fontMatrix = const <num>[];
  List<num> fontBBox = const <num>[];
  int uniqueID = 0;
  double strokeWidth = 0;
  String fontID = '';

  // FontInfo dictionary
  String version = '';
  String notice = '';
  String fullName = '';
  String familyName = '';
  String weight = '';
  double italicAngle = 0;
  bool fixedPitch = false;
  double underlinePosition = 0;
  double underlineThickness = 0;

  // Private dictionary
  List<num> blueValues = const <num>[];
  List<num> otherBlues = const <num>[];
  List<num> familyBlues = const <num>[];
  List<num> familyOtherBlues = const <num>[];
  double blueScale = 0;
  int blueShift = 0;
  int blueFuzz = 0;
  List<num> stdHW = const <num>[];
  List<num> stdVW = const <num>[];
  List<num> stemSnapH = const <num>[];
  List<num> stemSnapV = const <num>[];
  bool forceBold = false;
  int languageGroup = 0;

  /// Local subroutine array.
  final List<Uint8List> subrs = <Uint8List>[];

  /// CharStrings dictionary in raw form.
  final LinkedHashMap<String, Uint8List> charStrings =
      LinkedHashMap<String, Uint8List>();

  final Map<String, Type1CharString> _charStringCache =
      <String, Type1CharString>{};
  Type1CharStringParser? _charStringParser;

  final Uint8List _segment1;
  final Uint8List _segment2;

  @override
  String getName() => fontName;

  /// Returns the PostScript font name.
  String getFontName() => fontName;

  @override
  CharStringPath getPath(String name) => getType1CharString(name).getPath();

  @override
  double getWidth(String name) => getType1CharString(name).getWidth();

  @override
  bool hasGlyph(String name) => charStrings.containsKey(name);

  @override
  Type1CharString getType1CharString(String name) {
    final cached = _charStringCache[name];
    if (cached != null) {
      return cached;
    }

    var bytes = charStrings[name];
    if (bytes == null) {
      bytes = charStrings['.notdef'];
      if (bytes == null) {
        throw IOException('.notdef is not defined');
      }
    }

    final sequence = _getParser().parse(bytes, subrs, name);
    final type1 = Type1CharString(this, fontName, name, sequence);
    _charStringCache[name] = type1;
    return type1;
  }

  Type1CharStringParser _getParser() {
    return _charStringParser ??= Type1CharStringParser(fontName);
  }

  /// Returns an unmodifiable view of the Subrs array.
  List<Uint8List> getSubrsArray() => List<Uint8List>.unmodifiable(subrs);

  /// Returns the CharStrings dictionary as unmodifiable map.
  Map<String, Uint8List> getCharStringsDict() =>
      Map<String, Uint8List>.unmodifiable(charStrings);

  @override
  Encoding? getEncoding() => encoding;

  /// Returns the font paint type.
  int getPaintType() => paintType;

  /// Returns the font type.
  int getFontType() => fontType;

  @override
  List<num> getFontMatrix() => List<num>.unmodifiable(
        fontMatrix.isEmpty ? _defaultFontMatrix : fontMatrix,
      );

  @override
  BoundingBox getFontBBox() {
    final bbox = fontBBox;
    if (bbox.length < 4) {
      throw IOException('FontBBox must have 4 numbers, but is $bbox');
    }
    return BoundingBox.fromNumbers(bbox);
  }

  /// Returns the unique font identifier when present.
  int getUniqueID() => uniqueID;

  /// Returns the declared stroke width.
  double getStrokeWidth() => strokeWidth;

  /// Returns the optional font identifier.
  String getFontID() => fontID;

  /// Returns the version string from FontInfo.
  String getVersion() => version;

  /// Returns the notice string from FontInfo.
  String getNotice() => notice;

  /// Returns the full name from FontInfo.
  String getFullName() => fullName;

  /// Returns the family name from FontInfo.
  String getFamilyName() => familyName;

  /// Returns the weight string from FontInfo.
  String getWeight() => weight;

  /// Returns the italic angle in degrees.
  double getItalicAngle() => italicAngle;

  /// Returns true when the font declares a fixed pitch.
  bool isFixedPitch() => fixedPitch;

  /// Returns the underline position metric.
  double getUnderlinePosition() => underlinePosition;

  /// Returns the underline thickness metric.
  double getUnderlineThickness() => underlineThickness;

  /// Returns the blue values array from the Private dictionary.
  List<num> getBlueValues() => List<num>.unmodifiable(blueValues);

  /// Returns the other blues array from the Private dictionary.
  List<num> getOtherBlues() => List<num>.unmodifiable(otherBlues);

  /// Returns the family blues array from the Private dictionary.
  List<num> getFamilyBlues() => List<num>.unmodifiable(familyBlues);

  /// Returns the family other blues array from the Private dictionary.
  List<num> getFamilyOtherBlues() => List<num>.unmodifiable(familyOtherBlues);

  /// Returns the blue scale parameter.
  double getBlueScale() => blueScale;

  /// Returns the blue shift parameter.
  int getBlueShift() => blueShift;

  /// Returns the blue fuzz parameter.
  int getBlueFuzz() => blueFuzz;

  /// Returns the StdHW array from the Private dictionary.
  List<num> getStdHW() => List<num>.unmodifiable(stdHW);

  /// Returns the StdVW array from the Private dictionary.
  List<num> getStdVW() => List<num>.unmodifiable(stdVW);

  /// Returns the StemSnapH array from the Private dictionary.
  List<num> getStemSnapH() => List<num>.unmodifiable(stemSnapH);

  /// Returns the StemSnapV array from the Private dictionary.
  List<num> getStemSnapV() => List<num>.unmodifiable(stemSnapV);

  /// Returns `true` when the font forces bold rendering.
  bool isForceBold() => forceBold;

  /// Returns the language group value from the Private dictionary.
  int getLanguageGroup() => languageGroup;

  /// Returns the ASCII segment of the underlying PFB program.
  Uint8List getASCIISegment() => Uint8List.fromList(_segment1);

  /// Returns the binary segment of the underlying PFB program.
  Uint8List getBinarySegment() => Uint8List.fromList(_segment2);

  @override
  String toString() {
    return 'Type1Font[fontName=$fontName, fullName=$fullName, encoding=$encoding, '
        'charStrings=${charStrings.length}]';
  }
}
