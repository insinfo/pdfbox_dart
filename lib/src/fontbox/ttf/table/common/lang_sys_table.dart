class LangSysTable {
  LangSysTable(
    this.lookupOrder,
    this.requiredFeatureIndex,
    this.featureIndexCount,
    List<int> featureIndices,
  ) : featureIndices = List<int>.unmodifiable(featureIndices);

  final int lookupOrder;
  final int requiredFeatureIndex;
  final int featureIndexCount;
  final List<int> featureIndices;

  @override
  String toString() =>
      'LangSysTable[requiredFeatureIndex=$requiredFeatureIndex]';
}
