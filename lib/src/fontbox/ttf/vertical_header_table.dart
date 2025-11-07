import '../io/ttf_data_stream.dart';
import 'ttf_table.dart';

/// TrueType/OpenType 'vhea' table containing vertical header metrics.
class VerticalHeaderTable extends TtfTable {
  static const String tableTag = 'vhea';

  double _version = 1.0;
  int _ascender = 0;
  int _descender = 0;
  int _lineGap = 0;
  int _advanceHeightMax = 0;
  int _minTopSideBearing = 0;
  int _minBottomSideBearing = 0;
  int _yMaxExtent = 0;
  int _caretSlopeRise = 0;
  int _caretSlopeRun = 0;
  int _caretOffset = 0;
  int _reserved1 = 0;
  int _reserved2 = 0;
  int _reserved3 = 0;
  int _reserved4 = 0;
  int _metricDataFormat = 0;
  int _numberOfVMetrics = 0;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    _version = data.read32Fixed();
    _ascender = data.readSignedShort();
    _descender = data.readSignedShort();
    _lineGap = data.readSignedShort();
    _advanceHeightMax = data.readUnsignedShort();
    _minTopSideBearing = data.readSignedShort();
    _minBottomSideBearing = data.readSignedShort();
    _yMaxExtent = data.readSignedShort();
    _caretSlopeRise = data.readSignedShort();
    _caretSlopeRun = data.readSignedShort();
    _caretOffset = data.readSignedShort();
    _reserved1 = data.readSignedShort();
    _reserved2 = data.readSignedShort();
    _reserved3 = data.readSignedShort();
    _reserved4 = data.readSignedShort();
    _metricDataFormat = data.readSignedShort();
    _numberOfVMetrics = data.readUnsignedShort();
    setInitialized(true);
  }

  double get version => _version;
  int get ascender => _ascender;
  int get descender => _descender;
  int get lineGap => _lineGap;
  int get advanceHeightMax => _advanceHeightMax;
  int get minTopSideBearing => _minTopSideBearing;
  int get minBottomSideBearing => _minBottomSideBearing;
  int get yMaxExtent => _yMaxExtent;
  int get caretSlopeRise => _caretSlopeRise;
  int get caretSlopeRun => _caretSlopeRun;
  int get caretOffset => _caretOffset;
  int get reserved1 => _reserved1;
  int get reserved2 => _reserved2;
  int get reserved3 => _reserved3;
  int get reserved4 => _reserved4;
  int get metricDataFormat => _metricDataFormat;
  int get numberOfVMetrics => _numberOfVMetrics;
}

/// Protocol implemented by [TrueTypeFont] to provide vertical header lookup.
abstract class VerticalHeaderTableProvider {
  VerticalHeaderTable? getVerticalHeaderTable();
}
