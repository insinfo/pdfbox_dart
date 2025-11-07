class FeatureTable {
  FeatureTable(this.featureParams, this.lookupIndexCount, List<int> lookupListIndices)
      : lookupListIndices = List<int>.unmodifiable(lookupListIndices);

  final int featureParams;
  final int lookupIndexCount;
  final List<int> lookupListIndices;

  @override
  String toString() =>
      'FeatureTable[lookupListIndicesCount=${lookupListIndices.length}]';
}
