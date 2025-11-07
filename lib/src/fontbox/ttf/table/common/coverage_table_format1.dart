import 'coverage_table.dart';

class CoverageTableFormat1 extends CoverageTable {
  CoverageTableFormat1(int coverageFormat, List<int> glyphArray)
      : glyphArray = List<int>.unmodifiable(glyphArray),
        super(coverageFormat);

  final List<int> glyphArray;

  @override
  int getCoverageIndex(int glyphId) => _binarySearch(glyphArray, glyphId);

  @override
  int getGlyphId(int index) => glyphArray[index];

  @override
  int getSize() => glyphArray.length;

  @override
  String toString() =>
      'CoverageTableFormat1[coverageFormat=$coverageFormat,glyphArray=$glyphArray]';
}

int _binarySearch(List<int> values, int target) {
  var low = 0;
  var high = values.length - 1;
  while (low <= high) {
    final mid = low + ((high - low) >> 1);
    final midValue = values[mid];
    if (midValue < target) {
      low = mid + 1;
    } else if (midValue > target) {
      high = mid - 1;
    } else {
      return mid;
    }
  }
  return -(low + 1);
}
