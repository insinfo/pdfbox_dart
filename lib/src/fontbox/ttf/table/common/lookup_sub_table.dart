import 'coverage_table.dart';

abstract class LookupSubTable {
  const LookupSubTable(this.substFormat, this.coverageTable);

  final int substFormat;
  final CoverageTable coverageTable;

  int doSubstitution(int glyphId, int coverageIndex);
}
