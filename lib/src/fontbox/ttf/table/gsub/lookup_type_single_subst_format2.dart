import 'dart:collection';

import '../common/coverage_table.dart';
import '../common/lookup_sub_table.dart';

class LookupTypeSingleSubstFormat2 extends LookupSubTable {
  LookupTypeSingleSubstFormat2(
    int substFormat,
    CoverageTable coverageTable,
    List<int> substituteGlyphIds,
  )   : substituteGlyphIds = UnmodifiableListView<int>(substituteGlyphIds),
        super(substFormat, coverageTable);

  final List<int> substituteGlyphIds;

  @override
  int doSubstitution(int glyphId, int coverageIndex) =>
      coverageIndex < 0 ? glyphId : substituteGlyphIds[coverageIndex];

  @override
  String toString() =>
      'LookupTypeSingleSubstFormat2[substFormat=$substFormat,substituteGlyphIDs=$substituteGlyphIds]';
}
