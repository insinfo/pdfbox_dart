import '../io/ttf_data_stream.dart';
import 'cmap_subtable.dart';
import 'ttf_table.dart';

/// Required 'cmap' table mapping Unicode code points to glyph identifiers.
class CmapTable extends TtfTable {
  static const String tableTag = 'cmap';

  // Platform IDs
  static const int platformUnicode = 0;
  static const int platformMacintosh = 1;
  static const int platformIso = 2;
  static const int platformWindows = 3;
  static const int platformCustom = 4;

  // Unicode encodings
  static const int encodingUnicode10 = 0;
  static const int encodingUnicode11 = 1;
  static const int encodingUnicode20Bmp = 3;
  static const int encodingUnicode20Full = 4;

  // Windows encodings
  static const int encodingWinSymbol = 0;
  static const int encodingWinUnicodeBmp = 1;
  static const int encodingWinShiftJis = 2;
  static const int encodingWinUnicodeFull = 10;

  List<CmapSubtable> _cmaps = const <CmapSubtable>[];

  @override
  void read(dynamic ttf, TtfDataStream data) {
    data.readUnsignedShort(); // version, unused
    final numberOfTables = data.readUnsignedShort();
    final cmaps =
        List<CmapSubtable>.generate(numberOfTables, (_) => CmapSubtable());
    for (final cmap in cmaps) {
      cmap.initData(data);
    }

    final numberOfGlyphs = (ttf is HasGlyphCount) ? ttf.numberOfGlyphs : 0;
    for (final cmap in cmaps) {
      cmap.initSubtable(offset, numberOfGlyphs, data);
    }

    _cmaps = List<CmapSubtable>.unmodifiable(cmaps);
    setInitialized(true);
  }

  List<CmapSubtable> get cmaps => _cmaps;

  CmapSubtable? getSubtable(int platformId, int platformEncodingId) {
    for (final cmap in _cmaps) {
      if (cmap.platformId == platformId &&
          cmap.platformEncodingId == platformEncodingId) {
        return cmap;
      }
    }
    return null;
  }
}

/// Lightweight contract exposed by [TrueTypeFont] while the parser is still under port.
abstract class HasGlyphCount {
  int get numberOfGlyphs;
}
