import '../io/ttf_data_stream.dart';

/// Represents a record inside the TrueType/OpenType naming table.
class NameRecord {
  // Platform IDs
  static const int platformUnicode = 0;
  static const int platformMacintosh = 1;
  static const int platformIso = 2;
  static const int platformWindows = 3;

  // Unicode encoding IDs
  static const int encodingUnicode10 = 0;
  static const int encodingUnicode11 = 1;
  static const int encodingUnicode20Bmp = 3;
  static const int encodingUnicode20Full = 4;

  // Unicode language ID
  static const int languageUnicode = 0;

  // Windows encoding IDs
  static const int encodingWindowsSymbol = 0;
  static const int encodingWindowsUnicodeBmp = 1;
  static const int encodingWindowsUnicodeUcs4 = 10;

  // Windows language IDs
  static const int languageWindowsEnUs = 0x0409;

  // Macintosh encoding IDs
  static const int encodingMacintoshRoman = 0;

  // Macintosh language IDs
  static const int languageMacintoshEnglish = 0;

  // Name IDs
  static const int nameCopyright = 0;
  static const int nameFontFamilyName = 1;
  static const int nameFontSubFamilyName = 2;
  static const int nameUniqueFontId = 3;
  static const int nameFullFontName = 4;
  static const int nameVersion = 5;
  static const int namePostScriptName = 6;
  static const int nameTrademark = 7;

  int platformId = 0;
  int platformEncodingId = 0;
  int languageId = 0;
  int nameId = 0;
  int stringLength = 0;
  int stringOffset = 0;
  String? string;

  /// Reads the name record metadata (without the associated string).
  void readData(TtfDataStream data, {bool useLongOffsets = false}) {
    platformId = data.readUnsignedShort();
    platformEncodingId = data.readUnsignedShort();
    languageId = data.readUnsignedShort();
    nameId = data.readUnsignedShort();
    if (useLongOffsets) {
      stringLength = data.readUnsignedInt();
      stringOffset = data.readUnsignedInt();
    } else {
      stringLength = data.readUnsignedShort();
      stringOffset = data.readUnsignedShort();
    }
  }

  @override
  String toString() =>
      'NameRecord[platform=$platformId,encoding=$platformEncodingId,language=$languageId,name=$nameId,string=$string]';
}
