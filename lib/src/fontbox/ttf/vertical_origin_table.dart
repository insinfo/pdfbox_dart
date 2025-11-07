import '../io/ttf_data_stream.dart';
import 'ttf_table.dart';

/// OpenType 'VORG' table storing vertical origin coordinates for glyphs.
class VerticalOriginTable extends TtfTable {
  static const String tableTag = 'VORG';

  double _version = 1.0;
  int _defaultVertOriginY = 0;
  final Map<int, int> _origins = <int, int>{};

  @override
  void read(dynamic ttf, TtfDataStream data) {
    _version = data.read32Fixed();
    _defaultVertOriginY = data.readSignedShort();
    final numVertOriginYMetrics = data.readUnsignedShort();
    _origins.clear();
    for (var i = 0; i < numVertOriginYMetrics; i++) {
      final glyphId = data.readUnsignedShort();
      final originY = data.readSignedShort();
      _origins[glyphId] = originY;
    }
    setInitialized(true);
  }

  double get version => _version;
  int get defaultVertOriginY => _defaultVertOriginY;

  /// Returns the vertical origin Y coordinate for [gid], falling back to the default value.
  int getOriginY(int gid) => _origins[gid] ?? _defaultVertOriginY;

  Map<int, int> get origins => Map<int, int>.unmodifiable(_origins);
}
