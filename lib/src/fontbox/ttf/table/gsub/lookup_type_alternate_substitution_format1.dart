import 'dart:collection';

import '../common/coverage_table.dart';
import '../common/lookup_sub_table.dart';
import 'alternate_set_table.dart';

class LookupTypeAlternateSubstitutionFormat1 extends LookupSubTable {
  LookupTypeAlternateSubstitutionFormat1(
    int substFormat,
    CoverageTable coverageTable,
    List<AlternateSetTable> alternateSetTables,
  )   : alternateSetTables = UnmodifiableListView<AlternateSetTable>(alternateSetTables),
        super(substFormat, coverageTable);

  final List<AlternateSetTable> alternateSetTables;

  @override
  int doSubstitution(int glyphId, int coverageIndex) =>
      throw UnsupportedError('Alternate substitution selects glyph at runtime');
}
