import '../io/ttf_data_stream.dart';
import 'header_table.dart';
import 'ttf_table.dart';

/// TrueType 'loca' table mapping glyph indices to offsets within the glyf table.
class IndexToLocationTable extends TtfTable {
  static const String tableTag = 'loca';

  static const int shortOffsets = 0;
  static const int longOffsets = 1;

  late List<int> _offsets;

  List<int> get offsets => _offsets;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    final header = ttf is HeaderTableProvider ? ttf.getHeaderTable() : null;
    if (header == null) {
      throw StateError('Header table must be read before loca table');
    }

    final numGlyphs = ttf.numberOfGlyphs;
    _offsets = List<int>.filled(numGlyphs + 1, 0);
    for (var i = 0; i < numGlyphs + 1; i++) {
      if (header.indexToLocFormat == shortOffsets) {
        _offsets[i] = data.readUnsignedShort() * 2;
      } else if (header.indexToLocFormat == longOffsets) {
        _offsets[i] = data.readUnsignedInt();
      } else {
        throw StateError(
            'Unsupported indexToLocFormat ${header.indexToLocFormat}');
      }
    }

    if (numGlyphs == 1 && _offsets[0] == 0 && _offsets[1] == 0) {
      throw StateError('Font declares zero glyphs');
    }

    setInitialized(true);
  }
}

/// Protocol implemented by [TrueTypeFont] to provide header table lookups.
abstract class HeaderTableProvider {
  HeaderTable? getHeaderTable();
  int get numberOfGlyphs;
}
