import 'package:logging/logging.dart';

import '../io/ttf_data_stream.dart';
import 'kerning_subtable.dart';
import 'ttf_table.dart';

/// TrueType 'kern' table aggregating kerning subtables.
class KerningTable extends TtfTable {
  static const String tableTag = 'kern';
  static final Logger _log = Logger('fontbox.KerningTable');

  List<KerningSubtable> _subtables = const <KerningSubtable>[];

  @override
  void read(dynamic ttf, TtfDataStream data) {
    var version = data.readUnsignedShort();
    if (version != 0) {
      version = (version << 16) | data.readUnsignedShort();
    }

    var numSubtables = 0;
    switch (version) {
      case 0:
        numSubtables = data.readUnsignedShort();
        break;
      case 1:
        numSubtables = data.readUnsignedInt();
        break;
      default:
        _log.fine(
            'Skipped kerning table due to an unsupported kerning table version: $version');
        break;
    }

    if (numSubtables > 0) {
      final subtables = List<KerningSubtable>.generate(
          numSubtables, (_) => KerningSubtable());
      for (var i = 0; i < numSubtables; ++i) {
        subtables[i].read(data, version);
      }
      _subtables = subtables;
    } else {
      _subtables = const <KerningSubtable>[];
    }

    setInitialized(true);
  }

  /// First subtable supporting horizontal kerning.
  KerningSubtable? getHorizontalKerningSubtable([bool cross = false]) {
    for (final subtable in _subtables) {
      if (subtable.isHorizontalKerning(cross)) {
        return subtable;
      }
    }
    return null;
  }

  List<KerningSubtable> get subtables =>
      List<KerningSubtable>.unmodifiable(_subtables);
}
