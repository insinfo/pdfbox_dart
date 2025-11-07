import 'coverage_table_format1.dart';
import 'range_record.dart';

class CoverageTableFormat2 extends CoverageTableFormat1 {
  CoverageTableFormat2(int coverageFormat, List<RangeRecord> rangeRecords)
      : rangeRecords = List<RangeRecord>.unmodifiable(rangeRecords),
        super(coverageFormat, _expandRanges(rangeRecords));

  final List<RangeRecord> rangeRecords;

  static List<int> _expandRanges(List<RangeRecord> ranges) {
    if (ranges.isEmpty) {
      return const <int>[];
    }
    final glyphIds = <int>[];
    for (final range in ranges) {
      for (var glyphId = range.startGlyphId;
          glyphId <= range.endGlyphId;
          glyphId++) {
        glyphIds.add(glyphId);
      }
    }
    return List<int>.unmodifiable(glyphIds);
  }

  @override
  String toString() => 'CoverageTableFormat2[coverageFormat=$coverageFormat]';
}
