import '../../io/random_access_read_buffer.dart';
import '../io/random_access_read_data_stream.dart';
import '../io/ttf_data_stream.dart';
import 'glyph_data.dart';
import 'horizontal_metrics_table.dart';
import 'index_to_location_table.dart';
import 'maximum_profile_table.dart';
import 'ttf_table.dart';

/// TrueType 'glyf' table storing glyph outlines.
class GlyphTable extends TtfTable {
  static const String tableTag = 'glyf';

  static const int _maxCacheSize = 5000;
  static const int _maxCachedGlyphs = 100;

  List<GlyphData?>? _glyphs;
  late RandomAccessReadDataStream _data;
  late IndexToLocationTable _loca;
  HorizontalMetricsTable? _horizontalMetrics;
  MaximumProfileTable? _maximumProfile;
  int _cachedGlyphs = 0;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    if (ttf is! GlyphTableDependencies) {
      throw StateError('TrueTypeFont must implement GlyphTableDependencies');
    }

    final dependencies = ttf;
    final loca = dependencies.getIndexToLocationTable();
    if (loca == null) {
      throw StateError('IndexToLocationTable must be parsed before GlyphTable');
    }
    _loca = loca;

    final numGlyphs = dependencies.numberOfGlyphs;
    if (numGlyphs < _maxCacheSize) {
      _glyphs = List<GlyphData?>.filled(numGlyphs, null, growable: false);
    }

    final bytes = data.readBytes(length);
    final buffer = RandomAccessReadBuffer.fromBytes(bytes);
    _data = RandomAccessReadDataStream.fromRandomAccessRead(buffer);

    _horizontalMetrics = dependencies.getHorizontalMetricsTable();
    _maximumProfile = dependencies.getMaximumProfileTable();

    setInitialized(true);
  }

  GlyphData? getGlyph(int gid, [int level = 0]) {
    final glyphCount = _glyphs?.length ?? _loca.offsets.length - 1;
    if (gid < 0 || gid >= glyphCount) {
      return null;
    }

    final cachedGlyph = _glyphs != null ? _glyphs![gid] : null;
    if (cachedGlyph != null) {
      return cachedGlyph;
    }

    final offsets = _loca.offsets;
    if (offsets[gid] == offsets[gid + 1] ||
        offsets[gid] == _data.originalDataSize) {
      final glyph = GlyphData()..initEmptyData();
      _cacheGlyph(gid, glyph);
      return glyph;
    }

    final savedPosition = _data.currentPosition;
    _data.seek(offsets[gid]);
    final glyph = _readGlyph(gid, level);
    _data.seek(savedPosition);
    _cacheGlyph(gid, glyph);
    return glyph;
  }

  void _cacheGlyph(int gid, GlyphData glyph) {
    if (_glyphs == null) {
      return;
    }
    if (_glyphs![gid] == null && _cachedGlyphs < _maxCachedGlyphs) {
      _glyphs![gid] = glyph;
      _cachedGlyphs++;
    }
  }

  GlyphData _readGlyph(int gid, int level) {
    final maxDepth = _maximumProfile?.maxComponentDepth ?? 0;
    if (maxDepth > 0 && level > maxDepth) {
      throw StateError('Composite glyph recursion limit exceeded');
    }

    final glyph = GlyphData();
    final leftSideBearing = _horizontalMetrics?.getLeftSideBearing(gid) ?? 0;
    glyph.initData(this, _data, leftSideBearing, level);

    final description = glyph.description;
    if (description != null && description.isComposite) {
      description.resolve();
    }
    return glyph;
  }
}

/// Protocol implemented by [TrueTypeFont] to provide dependencies required
/// by [GlyphTable].
abstract class GlyphTableDependencies
    implements HeaderTableProvider, HorizontalHeaderTableProvider {
  IndexToLocationTable? getIndexToLocationTable();
  HorizontalMetricsTable? getHorizontalMetricsTable();
  MaximumProfileTable? getMaximumProfileTable();
  int get numberOfGlyphs;
}
