import '../io/ttf_data_stream.dart';
import 'font_headers.dart';
import 'ttf_table.dart';

/// TrueType 'head' table containing global font metrics.
class HeaderTable extends TtfTable {
  static const String tableTag = 'head';

  static const int macStyleBold = 1;
  static const int macStyleItalic = 2;

  double version = 0;
  double fontRevision = 0;
  int checkSumAdjustment = 0;
  int magicNumber = 0;
  int flags = 0;
  int unitsPerEm = 0;
  DateTime? created;
  DateTime? modified;
  int xMin = 0;
  int yMin = 0;
  int xMax = 0;
  int yMax = 0;
  int macStyle = 0;
  int lowestRecPpem = 0;
  int fontDirectionHint = 0;
  int indexToLocFormat = 0;
  int glyphDataFormat = 0;

  @override
  void readHeaders(dynamic ttf, TtfDataStream data, FontHeaders outHeaders) {
    // Skip fields parsed in [read] and capture macStyle early for quick access.
    data.seek(data.currentPosition + 44);
    macStyle = data.readUnsignedShort();
    outHeaders.setHeaderMacStyle(macStyle);
  }

  @override
  void read(dynamic ttf, TtfDataStream data) {
    version = data.read32Fixed();
    fontRevision = data.read32Fixed();
    checkSumAdjustment = data.readUnsignedInt();
    magicNumber = data.readUnsignedInt();
    flags = data.readUnsignedShort();
    unitsPerEm = data.readUnsignedShort();
    created = data.readInternationalDate();
    modified = data.readInternationalDate();
    xMin = data.readSignedShort();
    yMin = data.readSignedShort();
    xMax = data.readSignedShort();
    yMax = data.readSignedShort();
    macStyle = data.readUnsignedShort();
    lowestRecPpem = data.readUnsignedShort();
    fontDirectionHint = data.readSignedShort();
    indexToLocFormat = data.readSignedShort();
    glyphDataFormat = data.readSignedShort();
    setInitialized(true);
  }
}
