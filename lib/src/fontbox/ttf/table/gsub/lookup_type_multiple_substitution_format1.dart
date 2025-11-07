import 'dart:collection';

import '../common/coverage_table.dart';
import '../common/lookup_sub_table.dart';
import 'sequence_table.dart';

class LookupTypeMultipleSubstitutionFormat1 extends LookupSubTable {
  LookupTypeMultipleSubstitutionFormat1(
    int substFormat,
    CoverageTable coverageTable,
    List<SequenceTable> sequenceTables,
  )   : sequenceTables = UnmodifiableListView<SequenceTable>(sequenceTables),
        super(substFormat, coverageTable);

  final List<SequenceTable> sequenceTables;

  @override
  int doSubstitution(int glyphId, int coverageIndex) =>
      throw UnsupportedError('Multiple substitution expands glyph sequences');
}
