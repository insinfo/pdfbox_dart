import 'dart:collection';

import '../common/coverage_table.dart';
import '../common/lookup_sub_table.dart';
import 'ligature_set_table.dart';

class LookupTypeLigatureSubstitutionSubstFormat1 extends LookupSubTable {
  LookupTypeLigatureSubstitutionSubstFormat1(
    int substFormat,
    CoverageTable coverageTable,
    List<LigatureSetTable> ligatureSetTables,
  )   : ligatureSetTables =
            UnmodifiableListView<LigatureSetTable>(ligatureSetTables),
        super(substFormat, coverageTable);

  final List<LigatureSetTable> ligatureSetTables;

  @override
  int doSubstitution(int glyphId, int coverageIndex) => throw UnsupportedError(
      'Ligature substitution emits composed glyph sequences');

  @override
  String toString() =>
      'LookupTypeLigatureSubstitutionSubstFormat1[substFormat=$substFormat]';
}
