import 'feature_table.dart';

class FeatureRecord {
  const FeatureRecord(this.featureTag, this.featureTable);

  final String featureTag;
  final FeatureTable featureTable;

  @override
  String toString() => 'FeatureRecord[featureTag=$featureTag]';
}
