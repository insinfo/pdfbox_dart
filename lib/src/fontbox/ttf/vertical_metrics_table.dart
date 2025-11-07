import '../io/ttf_data_stream.dart';
import 'cmap_table.dart' show HasGlyphCount;
import 'ttf_table.dart';
import 'vertical_header_table.dart';

/// TrueType/OpenType 'vmtx' table containing vertical advance heights and bearings.
class VerticalMetricsTable extends TtfTable {
  static const String tableTag = 'vmtx';

  List<int> _advanceHeight = const <int>[];
  List<int> _topSideBearing = const <int>[];
  List<int> _additionalTopSideBearing = const <int>[];
  int _numVMetrics = 0;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    if (ttf is! VerticalHeaderTableProvider) {
      throw StateError(
          'Vertical header table must be available before reading vmtx');
    }
    if (ttf is! HasGlyphCount) {
      throw StateError('Glyph count required to parse vertical metrics table');
    }

    final header = ttf.getVerticalHeaderTable();
    if (header == null) {
      throw StateError('Vertical header table not found');
    }

    _numVMetrics = header.numberOfVMetrics;
    final numGlyphs = (ttf as HasGlyphCount).numberOfGlyphs;

    final advance = List<int>.filled(_numVMetrics, 0);
    final topBearing = List<int>.filled(_numVMetrics, 0);
    var bytesRead = 0;
    for (var i = 0; i < _numVMetrics; i++) {
      advance[i] = data.readUnsignedShort();
      topBearing[i] = data.readSignedShort();
      bytesRead += 4;
    }

    var numberNonVertical = numGlyphs - _numVMetrics;
    if (numberNonVertical < 0) {
      numberNonVertical = numGlyphs;
    }

    List<int> additional;
    if (numberNonVertical > 0) {
      additional = List<int>.filled(numberNonVertical, 0);
      if (bytesRead < length) {
        for (var i = 0; i < numberNonVertical && bytesRead < length; i++) {
          additional[i] = data.readSignedShort();
          bytesRead += 2;
        }
      }
    } else {
      additional = const <int>[];
    }

    _advanceHeight = advance;
    _topSideBearing = topBearing;
    _additionalTopSideBearing = additional;
    setInitialized(true);
  }

  int getAdvanceHeight(int gid) {
    if (_advanceHeight.isEmpty) {
      return 0;
    }
    if (gid < _numVMetrics) {
      return _advanceHeight[gid];
    }
    return _advanceHeight.last;
  }

  int getTopSideBearing(int gid) {
    if (_topSideBearing.isEmpty) {
      return 0;
    }
    if (gid < _numVMetrics) {
      return _topSideBearing[gid];
    }
    final index = gid - _numVMetrics;
    if (_additionalTopSideBearing.isEmpty) {
      return 0;
    }
    if (index >= 0 && index < _additionalTopSideBearing.length) {
      return _additionalTopSideBearing[index];
    }
    return _additionalTopSideBearing.isEmpty
        ? 0
        : _additionalTopSideBearing.last;
  }
}
