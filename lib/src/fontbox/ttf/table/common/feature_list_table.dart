import 'feature_record.dart';

class FeatureListTable {
  FeatureListTable(this.featureCount, List<FeatureRecord> featureRecords)
      : featureRecords = List<FeatureRecord>.unmodifiable(featureRecords);

  final int featureCount;
  final List<FeatureRecord> featureRecords;

  @override
  String toString() => 'FeatureListTable[featureCount=$featureCount]';
}
