import '../common/coverage_table.dart';
import '../common/lookup_sub_table.dart';

class LookupTypeSingleSubstFormat1 extends LookupSubTable {
  LookupTypeSingleSubstFormat1(int substFormat, CoverageTable coverageTable, this.deltaGlyphId)
      : super(substFormat, coverageTable);

  final int deltaGlyphId;

  @override
  int doSubstitution(int glyphId, int coverageIndex) =>
      coverageIndex < 0 ? glyphId : glyphId + deltaGlyphId;

  @override
  String toString() =>
      'LookupTypeSingleSubstFormat1[substFormat=$substFormat,deltaGlyphID=$deltaGlyphId]';
}
