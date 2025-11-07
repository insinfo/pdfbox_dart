/// Represents a contiguous range entry inside a coverage table (format 2).
class RangeRecord {
  const RangeRecord(this.startGlyphId, this.endGlyphId, this.startCoverageIndex)
      : assert(
            startGlyphId <= endGlyphId, 'startGlyphId must be <= endGlyphId');

  final int startGlyphId;
  final int endGlyphId;
  final int startCoverageIndex;

  @override
  String toString() =>
      'RangeRecord[startGlyphID=$startGlyphId,endGlyphID=$endGlyphId,startCoverageIndex=$startCoverageIndex]';
}
