import '../io/ttf_data_stream.dart';
import 'cmap_table.dart' show HasGlyphCount;
import 'horizontal_header_table.dart';
import 'ttf_table.dart';

/// TrueType 'hmtx' table storing advance widths and left side bearings.
class HorizontalMetricsTable extends TtfTable {
  static const String tableTag = 'hmtx';

  List<int> _advanceWidth = const <int>[];
  List<int> _leftSideBearing = const <int>[];
  List<int> _nonHorizontalLeftSideBearing = const <int>[];
  int _numHMetrics = 0;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    if (ttf is! HorizontalHeaderTableProvider) {
      throw StateError(
          'Horizontal header table is required before reading hmtx');
    }
    if (ttf is! HasGlyphCount) {
      throw StateError('Glyph count required to parse hmtx table');
    }

    final header = ttf.getHorizontalHeaderTable();
    if (header == null) {
      throw StateError('Horizontal header table not available');
    }

    _numHMetrics = header.numberOfHMetrics;
    final numGlyphs = ttf.numberOfGlyphs;

    final advance = List<int>.filled(_numHMetrics, 0);
    final left = List<int>.filled(_numHMetrics, 0);
    var bytesRead = 0;
    for (var i = 0; i < _numHMetrics; i++) {
      advance[i] = data.readUnsignedShort();
      left[i] = data.readSignedShort();
      bytesRead += 4;
    }

    var numberNonHorizontal = numGlyphs - _numHMetrics;
    if (numberNonHorizontal < 0) {
      numberNonHorizontal = numGlyphs;
    }

    final nonHorizontal = List<int>.filled(numberNonHorizontal, 0);
    if (bytesRead < length) {
      for (var i = 0; i < numberNonHorizontal && bytesRead < length; i++) {
        nonHorizontal[i] = data.readSignedShort();
        bytesRead += 2;
      }
    }

    _advanceWidth = advance;
    _leftSideBearing = left;
    _nonHorizontalLeftSideBearing = nonHorizontal;
    setInitialized(true);
  }

  int getAdvanceWidth(int gid) {
    if (_advanceWidth.isEmpty) {
      return 250;
    }
    if (gid < _numHMetrics) {
      return _advanceWidth[gid];
    }
    return _advanceWidth.last;
  }

  int getLeftSideBearing(int gid) {
    if (_leftSideBearing.isEmpty) {
      return 0;
    }
    if (gid < _numHMetrics) {
      return _leftSideBearing[gid];
    }
    final index = gid - _numHMetrics;
    if (_nonHorizontalLeftSideBearing.isEmpty) {
      return 0;
    }
    if (index >= 0 && index < _nonHorizontalLeftSideBearing.length) {
      return _nonHorizontalLeftSideBearing[index];
    }
    return _nonHorizontalLeftSideBearing.isEmpty
        ? 0
        : _nonHorizontalLeftSideBearing.last;
  }
}

/// Protocol implemented by [TrueTypeFont] to provide table lookups without
/// introducing circular imports.
abstract class HorizontalHeaderTableProvider {
  HorizontalHeaderTable? getHorizontalHeaderTable();
  int get numberOfGlyphs;
}
