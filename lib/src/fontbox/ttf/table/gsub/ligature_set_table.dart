import 'dart:collection';

import 'ligature_table.dart';

/// Groups ligatures that share the same initial glyph.
class LigatureSetTable {
  LigatureSetTable(int ligatureCount, List<LigatureTable> ligatureTables)
      : ligatureCount = ligatureCount,
        ligatureTables = UnmodifiableListView<LigatureTable>(ligatureTables);

  final int ligatureCount;
  final List<LigatureTable> ligatureTables;

  @override
  String toString() => 'LigatureSetTable[ligatureCount=$ligatureCount]';
}
