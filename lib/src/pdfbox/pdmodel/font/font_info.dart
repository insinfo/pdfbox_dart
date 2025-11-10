import '../../../fontbox/font_box_font.dart';
import 'cid_system_info.dart';
import 'font_format.dart';
import 'pd_panose_classification.dart';

/// Metadata describing a system font available to PDFBox.
abstract class FontInfo {
  /// Returns the PostScript name of the font.
  String get postScriptName;

  /// Returns the format of the font file.
  FontFormat get format;

  /// Returns the CIDSystemInfo when available.
  CidSystemInfo? get cidSystemInfo;

  /// Creates a new FontBox font instance representing this font.
  FontBoxFont getFont();

  /// Returns the sFamilyClass field of the OS/2 table, or -1 when unknown.
  int get familyClass;

  /// Returns the usWeightClass field of the OS/2 table, or -1 when unknown.
  int get weightClass;

  /// Returns the ulCodePageRange1 field of the OS/2 table, or 0 when absent.
  int get codePageRange1;

  /// Returns the ulCodePageRange2 field of the OS/2 table, or 0 when absent.
  int get codePageRange2;

  /// Returns the macStyle field of the head table, or -1 when unknown.
  int get macStyle;

  /// Returns the Panose classification when the font provides one.
  PDPanoseClassification? get panose;

  /// Maps the usWeightClass field to the Panose weight scale.
  int getWeightClassAsPanose() {
    switch (weightClass) {
      case -1:
      case 0:
        return 0;
      case 100:
        return 2;
      case 200:
        return 3;
      case 300:
        return 4;
      case 400:
        return 5;
      case 500:
        return 6;
      case 600:
        return 7;
      case 700:
        return 8;
      case 800:
        return 9;
      case 900:
        return 10;
      default:
        return 0;
    }
  }

  /// Combines the code page ranges into a single 64-bit mask.
  int getCodePageRange() {
    final range1 = codePageRange1 & 0x00000000ffffffff;
    final range2 = codePageRange2 & 0x00000000ffffffff;
    return (range2 << 32) | range1;
  }

  @override
  String toString() {
    final cid = cidSystemInfo;
    final cidDescription = cid != null ? cid.toString() : 'null';
    return '$postScriptName ($format, mac: 0x${macStyle.toRadixString(16)}, '
        'os/2: 0x${familyClass.toRadixString(16)}, cid: $cidDescription)';
  }
}
