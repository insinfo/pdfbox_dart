import '../io/ttf_data_stream.dart';
import 'ttf_table.dart';

/// TrueType 'hhea' table encoding horizontal layout metrics.
class HorizontalHeaderTable extends TtfTable {
  static const String tableTag = 'hhea';

  double version = 0;
  int ascender = 0;
  int descender = 0;
  int lineGap = 0;
  int advanceWidthMax = 0;
  int minLeftSideBearing = 0;
  int minRightSideBearing = 0;
  int xMaxExtent = 0;
  int caretSlopeRise = 0;
  int caretSlopeRun = 0;
  int reserved1 = 0;
  int reserved2 = 0;
  int reserved3 = 0;
  int reserved4 = 0;
  int reserved5 = 0;
  int metricDataFormat = 0;
  int numberOfHMetrics = 0;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    version = data.read32Fixed();
    ascender = data.readSignedShort();
    descender = data.readSignedShort();
    lineGap = data.readSignedShort();
    advanceWidthMax = data.readUnsignedShort();
    minLeftSideBearing = data.readSignedShort();
    minRightSideBearing = data.readSignedShort();
    xMaxExtent = data.readSignedShort();
    caretSlopeRise = data.readSignedShort();
    caretSlopeRun = data.readSignedShort();
    reserved1 = data.readSignedShort();
    reserved2 = data.readSignedShort();
    reserved3 = data.readSignedShort();
    reserved4 = data.readSignedShort();
    reserved5 = data.readSignedShort();
    metricDataFormat = data.readSignedShort();
    numberOfHMetrics = data.readUnsignedShort();
    setInitialized(true);
  }
}
